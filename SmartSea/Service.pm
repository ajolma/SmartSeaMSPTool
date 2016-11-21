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

my $allow_edit = 1;

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
                                     allow_edit => $allow_edit
                                   }
            ) if /rules([\/\?\w]*)$/;
        return $self->impact_network() if /impact_network$/;
        return $self->class_editor('SmartSea::Schema::Result::Dataset',
                                   $1, 
                                   { empty_is_null => [qw/contact desc attribution disclaimer path/],
                                     defaults => {},
                                     allow_edit => $allow_edit
                                   }
            ) if /datasets([\/\?\w]*)$/;

        return $self->class_editor('SmartSea::Schema::Result::Activity2Pressure',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     allow_edit => $allow_edit
                                   }
            ) if /activity2pressure([\/\?\w]*)$/;

        return $self->class_editor('SmartSea::Schema::Result::Impact',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     allow_edit => $allow_edit
                                   }
            ) if /impact([\/\?\w]*)$/;

        return $self->pressure_table($1) if /pressure_table([\/\?\w]*)$/;
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
        [li => $html->a(link => 'datasets', url  => $uri.'datasets')],
        [li => $html->a(link => 'activity -> pressure links', url  => $uri.'activity2pressure')],
        [li => $html->a(link => 'impacts', url  => $uri.'impact')],
        [li => $html->a(link => 'pressure table', url  => $uri.'pressure_table')]
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
                for my $rule (SmartSea::Schema::Result::Rule::rules($rules_rs, $plan, $use, $rel->layer)) {
                    push @r_u_layers, {
                        id => $rule->id,
                        text => $rule->as_text,
                        active => JSON::true
                    };
                }
                push @r_uses, {
                    id => $rel->layer->id,
                    use => $use->id,
                    layer => $rel->layer->title,
                    rules => \@r_u_layers
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

    my $activities = $self->{schema}->resultset('Activity');
    my $pressures = $self->{schema}->resultset('Pressure');
    my $aps = $self->{schema}->resultset('Activity2Pressure');
    my $components = $self->{schema}->resultset('EcosystemComponent');
    my $impacts = $self->{schema}->resultset('Impact');

    my @activities = $activities->search(undef, {order_by => ['me.id']});
    my @pressures = $pressures->search(undef, {order_by => ['me.id']});
    my @aps = $aps->search(undef, {order_by => ['me.id']});
    my @components = $components->search(undef, {order_by => ['me.id']});
    my @impacts = $impacts->search(undef, {order_by => ['me.id']});

    for my $activity (@activities) {
        push @{$elements{nodes}}, { data => { id => 'a'.$activity->id, name => $activity->title }};
    }
    for my $pressure (@pressures) {
        push @{$elements{nodes}}, { data => { id => 'p'.$pressure->id, name => $pressure->title }};
    }
    for my $ap (@aps) {
        push @{$elements{nodes}}, { data => { id => 'ap'.$ap->id, name => 'ap'.$ap->id }};
    }
    for my $component (@components) {
        push @{$elements{nodes}}, { data => { id => 'c'.$component->id, name => $component->title }};
    }
    for my $impact (@impacts) {
        push @{$elements{nodes}}, { data => { id => 'i'.$impact->id, name => 'i'.$impact->id }};
    }

    # activity, pressure -> ap
    for my $ap (@aps) {
        push @{$elements{edges}}, { data => { 
            source => 'a'.$ap->activity->id, 
            target => 'ap'.$ap->id }};
        push @{$elements{edges}}, { data => { 
            source => 'p'.$ap->pressure->id, 
            target => 'ap'.$ap->id }};
    }

    # ap, component -> impact
    for my $impact (@impacts) {
        push @{$elements{edges}}, { data => { 
            source => 'ap'.$impact->activity2pressure->id, 
            target => 'i'.$impact->id }};
        push @{$elements{edges}}, { data => { 
            source => 'c'.$impact->ecosystem_component->id, 
            target => 'i'.$impact->id }};
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
                  $class->HTML_form($self, \%parameters) ]
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
        $uri =~ s/\?edit$//;
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

sub pressure_table {
    my ($self, $x) = @_;
    my $aps = $self->{schema}->resultset('Activity2Pressure');
    my $pressures = $self->{schema}->resultset('Pressure');
    my %title;
    my %id;
    my %pressures;
    for my $pressure ($pressures->all) {
        $pressures{$pressure->title} = $pressure->order;
        $id{pressures}{$pressure->title} = $pressure->id;
    }
    my $activities = $self->{schema}->resultset('Activity');
    my %activities;
    for my $activity ($activities->all) {
        $activities{$activity->title} = $activity->order;
        $id{activities}{$activity->title} = $activity->id;
        $title{$activity->title} = $activity->title.'('.$activity->order.')';
    }
    for my $pressure ($pressures->all) {
        for my $activity ($activities->all) {
            my $key = 'range_'.$pressure->id.'_'.$activity->id;
            $title{$key} = $pressure->title.' '.$activity->title;
        }
    }
    
    #for my $key (sort $self->{parameters}->keys) {
    #    say STDERR "$key $self->{parameters}{$key}";
    #}

    my @error = ();

    my $submit = $self->{parameters}{submit} // '';
    if ($submit eq 'Commit') {
        my %have;
        for my $ap ($aps->all) {
            my $key = 'range_'.$ap->pressure->id.'_'.$ap->activity->id;
            $have{$key} = $ap->range;
        }
        for my $key ($self->{parameters}->keys) {
            next if $key eq 'submit';
            my $value = $self->{parameters}{$key};
            next if $value eq '0';
            my ($pressure, $activity) = $key =~ /range_(\d+)_(\d+)/;
            say STDERR "change $title{$key} ($have{$key}) to $value " if exists($have{$key}) && $have{$key} ne $value;
            say STDERR "insert $title{$key} $value" unless exists $have{$key};
            
            #$obj->update(\%parameters);

            unless (exists $have{$key}) {
                my $obj;
                eval {
                    $obj = $aps->create({pressure => $pressure, activity => $activity, range => $value});
                };
                if ($@ or not $obj) {
                    # if not ok, signal error
                    @error = (
                        [p => 'Something went wrong!'], 
                        [p => 'Error is: '.$@]
                        );
                }
            }
        }
    }
    
    my @rows;

    my @headers = ('Pressure', 'Activity', 'Range');
    my @tr;
    for my $h (@headers) {
        push @tr, [th => $h];
    }
    push @rows, [tr => \@tr];

    my %table;
    for my $ap ($aps->all) {
        $table{$ap->pressure->title}{$ap->activity->title} = $ap->range;
    }

    for my $pressure (sort {$pressures{$a} <=> $pressures{$b}} keys %pressures) {
        next unless $pressures{$pressure};
        my @activities;
        for my $activity (sort {$activities{$a} <=> $activities{$b}} keys %activities) {
            my $range = $table{$pressure}{$activity} // 0;
            next if $range < 0;
            push @activities, $activity;
        }
        my @td = ([td => {rowspan => $#activities+1}, $pressure]);
        for my $activity (@activities) {
            push @td, [td => $title{$activity}];
            my $range = $table{$pressure}{$activity} // 0;
            $range = SmartSea::HTML->text(
                name => 'range_'.$id{pressures}{$pressure}.'_'.$id{activities}{$activity},
                size => 10,
                visual => $range
                );
            push @td, [td => $range];
            push @rows, [tr => [@td]];
            @td = ();
        }
    }
    
    my @body = (
        @error,
        [ form => {action => $self->{uri}, method => 'POST'}, 
          [[a => {href => $self->{uri}}, 'reload'],
           [1 => "&nbsp;&nbsp;"],
           [input => {type => 'submit', name => 'submit', value => 'Commit'}],
           [table => {border => 1}, \@rows],
           [input => {type => 'submit', name => 'submit', value => 'Commit'}]]]
        );

    return html200(SmartSea::HTML->new(html => [body => \@body])->html);
}

1;
