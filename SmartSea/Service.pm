package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core;
use SmartSea::HTML;
use SmartSea::Schema;

use parent qw/Plack::Component/;

binmode STDERR, ":utf8"; 

sub new {
    my ($class, $self) = @_;
    $self = Plack::Component->new($self);
    my $dsn = "dbi:Pg:dbname=$self->{dbname}";
    $self->{schema} = SmartSea::Schema->connect($dsn, $self->{user}, $self->{pass}, {});
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    my $ret = common_responses($env);
    return $ret if $ret;
    my $request = Plack::Request->new($env);
    $self->{parameters} = $request->parameters;
    $self->{uri} = $env->{REQUEST_URI};
    for ($self->{uri}) {
        return $self->uses() if /uses$/;
        return $self->plans() if /plans$/;
        return $self->class_editor('SmartSea::Schema::Result::Rule', 
                                   $1, 
                                   { empty_is_null => ['value'], 
                                     defaults => {reduce=>1},
                                     allow_edit => 0
                                   }
            ) if /rules([\/\?\w]*)$/;
        return $self->impact_network() if /impact_network$/;
        return $self->class_editor('SmartSea::Schema::Result::Dataset',
                                   $1, 
                                   { empty_is_null => [qw/contact desc attribution disclaimer path/],
                                     defaults => {},
                                     allow_edit => 0
                                   }
            ) if /datasets([\/\?\w]*)$/;
        last;
    }
    my $html = SmartSea::HTML->new;
    my $uri = $self->{uri};
    $uri .= '/' unless $uri =~ /\/$/;
    my @l;
    push @l, (
        [li => $html->a(link => 'uses', url => $uri.'uses')],
        [li => $html->a(link => 'plans', url  => $uri.'plans')],
        [li => $html->a(link => 'rules', url  => $uri.'rules')],
        [li => $html->a(link => 'impact_network', url  => $uri.'impact_network')],
        [li => $html->a(link => 'datasets', url  => $uri.'datasets')]
    );
    return html200($html->html(html => [body => [ul => \@l]]));
}

sub uses {
    my $self = shift;
    my @uses;
    for my $use ($self->{schema}->resultset('Use')->search(undef, {order_by => ['me.id']})) {
        my @layers;
        my $rels = $use->use2layer->search(undef, {order_by => { -desc => 'me.layer'}});
        while (my $rel = $rels->next) {
            push @layers, {title => $rel->layer->title, my_id => $rel->layer->id};
        }
        push @uses, {
            title => $use->title,
            my_id => $use->id,
            layers => \@layers
        };
    }
    return json200(\@uses);
}

sub plans {
    my $self = shift;
    my $plans_rs = $self->{schema}->resultset('Plan');
    my $rules_rs = $self->{schema}->resultset('Rule');
    my $uses_rs = $self->{schema}->resultset('Use');
    my @plans;
    for my $plan ($plans_rs->search(undef, {order_by => ['me.title']})) {
        my @rules;
        for my $use ($uses_rs->search(undef, {order_by => ['me.id']})) {
            my @r_uses;
            my $rels = $use->use2layer->search(undef, {order_by => { -desc => 'me.layer'}});
            while (my $rel = $rels->next) {
                my @r_u_layers;
                my $remove_default;
                for my $rule ($rules_rs->search({ -or => [ plan => $plan->id,
                                                           plan => undef ],
                                                  use => $use->id,
                                                  layer => $rel->layer->id
                                                },
                                                { order_by => ['me.id'] })) {
                
                    # if there are rules for this plan, remove default rules
                    $remove_default = 1 if $rule->plan;
                    push @r_u_layers, {
                        id => $rule->id,
                        plan => $rule->plan,
                        text => $rule->as_text,
                        active => JSON::true
                    };
                    
                }
                my @final;
                for my $rule (@r_u_layers) {
                    next if $remove_default && !$rule->{plan};
                    delete $rule->{plan};
                    push @final, $rule;
                }

                push @r_uses, {
                    id => $rel->layer->id,
                    layer => $rel->layer->title,
                    rules => \@final
                }
            }
            
            push @rules, {
                use => $use->title,
                id => $use->id,
                rules => \@r_uses
            }
        }
        push @plans, {title => $plan->title, my_id => $plan->id, rules => \@rules};
    }
    return json200(\@plans);
}

sub impact_network {
    my $self = shift;

    my %elements = (nodes => [], edges => []);

    my $uses = $self->{schema}->resultset('Use');
    my $impacts = $self->{schema}->resultset('Impact');
    my $characteristics = $self->{schema}->resultset('Characteristic');

    for my $use ($uses->search(undef, {order_by => ['me.id']})) {
        push @{$elements{nodes}}, { data => { id => 'u'.$use->id, name => $use->title }};
    }
    for my $impact ($impacts->search(undef, {order_by => ['me.id']})) {
        push @{$elements{nodes}}, { data => { id => 'i'.$impact->id, name => $impact->title }};
    }
    for my $characteristic ($characteristics->search(undef, {order_by => ['me.id']})) {
        push @{$elements{nodes}}, { data => { id => 'c'.$characteristic->id, name => $characteristic->title }};
    }

    # uses -> impacts
    for my $use ($uses->search(undef, {order_by => ['me.id']})) {
        my $rels = $use->use2impact;
        while (my $rel = $rels->next) {
            push @{$elements{edges}}, { data => { 
                source => 'u'.$use->id, 
                target => 'i'.$rel->impact->id }};
        }
    }

    # impacts -> characteristics
    for my $impact ($impacts->search(undef, {order_by => ['me.id']})) {
        my $rels = $impact->impact2characteristic;
        while (my $rel = $rels->next) {
            push @{$elements{edges}}, { data => { 
                source => 'i'.$impact->id, 
                target => 'c'.$rel->characteristic->id }};
        }
    }

    return json200(\%elements);
}

sub class_editor {
    my ($self, $class, $oid, $config) = @_;

    # oid is what's after /objs in URI, it may have /new/ or /id/ (integer) in it
    # DBIx Class understands undef as NULL
    # config: delete => value-in-the-delete-button (default is Delete)
    #         store => value-in-the-store-button (default is Store)
    #         empty_is_null => parameters will be converted to undef if empty strings
    #         defaults => parameters will be set to the value unless in self->parameters
    # 'NULL' parameters will be converted to undef, 

    my $uri = $self->{uri};
    $uri =~ s/$oid$//;
    
    $config->{delete} //= 'Delete';
    $config->{store} //= 'Store';
    my $request = '';
    my %parameters;
    for my $p ($self->{parameters}->keys) {
        if ($p eq 'submit') {
            $request = $self->{parameters}{$p};
            next;
        }
        $parameters{$p} = $self->{parameters}{$p};
        if ($parameters{$p} eq $config->{delete}) {
            $request = $parameters{$p};
            $parameters{id} = $p;
            last;
        }
        $parameters{$p} = undef if $parameters{$p} eq 'NULL';
    }
    for my $col (@{$config->{empty_is_null}}) {
        $parameters{$col} = undef if exists $parameters{$col} && $parameters{$col} eq '';
    }
    for my $col (keys %{$config->{defaults}}) {
        $parameters{$col} = $config->{defaults}{$col} unless defined $parameters{$col};
    }

    my $rs = $self->{schema}->resultset($class =~ /(\w+)$/);

    my @body;

    if ($request eq $config->{delete} and $config->{allow_edit}) {

        eval {
            $rs->single({ id => $parameters{id} })->delete;
        };
        if ($@) {
            # if not ok, signal error
            push @body, [p => 'Something went wrong!'], [p => 'Error is: '.$@];
        }

    } elsif ($request eq $config->{store} and $config->{allow_edit}) {

        my $obj;
        eval {
            if (exists $parameters{id}) {
                $obj = $rs->single({ id => $parameters{id} });
                delete $parameters{id};
                $obj->update(\%parameters);
            } else {
                $obj = $rs->create(\%parameters);
            }
        };
        if ($@ or not $obj) {
            my $body = [];
            # if not ok, signal error and go back to form
            push @$body, (
                [p => 'Something went wrong!'], 
                [p => 'Error is: '.$@],
                [ form => { action => $uri, method => 'POST' },
                  $class->HTML_form(undef, $self, \%parameters) ]
            );
            return html200(SmartSea::HTML->new(html => [body => $body])->html);
        }
        
    } elsif ($oid =~ /new/ and $config->{allow_edit}) {

        my $body = [];
        push @$body, [form => { action => $uri, method => 'POST' },
                      $class->HTML_form($self, \%parameters)];
        return html200(SmartSea::HTML->new(html => [body => $body])->html);

    } elsif ($oid =~ /edit/ and $config->{allow_edit}) {

        ($oid) = $oid =~ /(\d+)/;
        my $obj = $rs->single({ id => $oid });
        return return_400 unless defined $obj;
        my $body = [form => { action => $uri, method => 'POST' },
                    $obj->HTML_form($self)];
        return html200(SmartSea::HTML->new(html => [body => $body])->html);
        
    } elsif ($oid) {

        ($oid) = $oid =~ /(\d+)/;
        my $obj = $rs->single({ id => $oid });
        return return_400 unless defined $obj;
        my $body = $obj->HTML_text($self, $self);
        $body = [form => { action => $uri, method => 'POST' }, $body] if $config->{allow_edit};
        return html200(SmartSea::HTML->new(html => [body => $body])->html);
        
    }

    push @body, @{$class->HTML_list($rs, $uri, $config->{allow_edit})};
    return html200(SmartSea::HTML->new(html => [body => \@body])->html);

}

1;
