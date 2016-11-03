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
        return $self->rules($1) if /rules\/?([\w]*)$/;
        return $self->impact_network() if /impact_network$/;
        return $self->dataset($1) if /datasets([\/\w]*)$/;
        last;
    }
    my $html = SmartSea::HTML->new;
    my @l;
    push @l, [li => $html->a(link => 'uses', url => $self->{uri}.'uses')];
    push @l, [li => $html->a(link => 'plans', url  => $self->{uri}.'plans')];
    push @l, [li => $html->a(link => 'rules', url  => $self->{uri}.'rules')];
    push @l, [li => $html->a(link => 'impact_network', url  => $self->{uri}.'impact_network')];
    push @l, [li => $html->a(link => 'datasets', url  => $self->{uri}.'datasets')];
    return html200($html->html(html => [body => [ul => \@l]]));
}

sub dataset {
    my ($self, $set) = @_;
    
    if ($set) {

        ($set) = $set =~ /(\d+)/;
        $set = $self->{schema}->resultset('Dataset')->single({ id => $set });
        
        my $body;
        if ($set) {
            my $info;
            if ($set->path =~ /^PG:/) {
                my $dsn = $set->path;
                $dsn =~ s/^PG://;
                $info = `ogrinfo -so PG:dbname=$self->{dbname} '$dsn'`;
            } else {
                my $path = $self->{data_path}.'/'.$set->path;
                $info = `gdalinfo $path`;
            }
            $body = [[h2 => "GDAL info of ".$set->name.":"], [pre => $info]];
            push @$body, $set->as_HTML_data;
        } else {
            $body = "dataset not found";
        }

        return html200(SmartSea::HTML->new(html => [body => $body])->html);

    } else {

        my $html = SmartSea::HTML->new;
        my @l;
        for $set ($self->{schema}->resultset('Dataset')->search({path => {'!=', undef}})) {
            push @l, [li => $html->a(link => $set->long_name, url => $self->{uri}.'/'.$set->id)];
        }
        return html200($html->html(html => [body => [ul => \@l]]));

    }
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
            my @rules_for_use;
            for my $rule ($rules_rs->search({ 'me.plan' => $plan->id,
                                              'me.use' => $use->id },
                                            { order_by => ['me.id'] })) {
                
                push @rules_for_use, {
                    id => $rule->id,
                    text => $rule->as_text,
                    active => JSON::true
                };
                
            }
            
            push @rules, {
                use => $use->title,
                id => $use->id,
                rules => \@rules_for_use
            }
            
        }
        push @plans, {title => $plan->title, my_id => $plan->id, rules => \@rules};
    }
    return json200(\@plans);
}

sub rules {
    my ($self, $rule) = @_;

    my %rule_parameters;
    my $delete;
    for my $p ($self->{parameters}->keys) {
        next if $p eq 'input';
        $rule_parameters{$p} = $self->{parameters}{$p};
        if ($rule_parameters{$p} eq 'Delete') {
            $delete = $p;
            last;
        }
        $rule_parameters{$p} = undef if $rule_parameters{$p} eq 'NULL';
    }
    $rule_parameters{value} = undef if exists $rule_parameters{value} && $rule_parameters{value} eq '';

    if (defined $delete) {
        $self->{schema}->resultset('Rule')->single({ id => $delete })->delete;
        return $self->list_rules;
    }

    if ($rule eq 'add') {

        my $body = [];

        if ($self->{parameters}{input}) {

            eval {
                $rule = $self->{schema}->resultset('Rule')->create(\%rule_parameters);
            };
            $rule = $@ if $@;
            
            # if ok, show list
            return $self->list_rules if ref $rule eq 'SmartSea::Schema::Result::Rule';
            
            # if not ok, signal error and go back to form
            push @$body, [p => 'No, this is not a good rule!'], [p => 'error is: '.$rule];
        }

        $rule_parameters{reduce} = 1 unless defined $rule_parameters{reduce};
        push @$body, [form => 
                      {
                          action => $self->{uri},
                          method => 'POST'
                      },
                      SmartSea::Schema::Result::Rule->HTML_form($self->{schema}, \%rule_parameters)];
        return html200(SmartSea::HTML->new(html => [body => $body])->html);

    } elsif ($rule) {

        my $rules_rs = $self->{schema}->resultset('Rule');
        ($rule) = $rule =~ /(\d+)/;
        $rule = $rules_rs->single({ id => $rule });
        return return_400 unless defined $rule;
        return html200(SmartSea::HTML->new(html => [body => $rule->HTML_form($self->{schema})])->html);

    } else {

        return $self->list_rules;

    }
}

sub list_rules {
    my $self = shift;
    my $rules_rs = $self->{schema}->resultset('Rule');
    my %data;
    my $html = SmartSea::HTML->new;
    for my $rule ($rules_rs->search(undef, {order_by => [qw/me.id/]})) {
        my $li = [
            $html->a(link => $rule->as_text, url => $self->{uri}.'/'.$rule->id),
            [1 => '  '],
            [input => {type=>"submit", name=>$rule->id, value=>"Delete"}]
        ];
        push @{$data{$rule->plan->title}{$rule->use->title}}, [li => $li];
    }
    my @body;
    for my $plan (sort keys %data) {
        my @l;
        for my $use (sort keys %{$data{$plan}}) {
            push @l, [li => [[b => $use], [ul => \@{$data{$plan}{$use}}]]];
        }
        push @body, [b => $plan], [ul => \@l];
    }
    push @body, $html->a(link => 'add', url => $self->{uri}.'/add');
    return html200($html->html(html => [body => [ 
                                            form => 
                                            {
                                                action => $self->{uri},
                                                method => 'POST'
                                            },\@body ]]));
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

1;
