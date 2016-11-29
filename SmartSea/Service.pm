package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Schema;
use Data::Dumper;

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
        return $self->plans($1) if /plans([\/\d]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::Plan',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /plan_browser([\/\?\w]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::Use',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /use_browser([\/\?\w]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::Activity',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /activity_browser([\/\?\w]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::EcosystemComponent',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /ec_browser([\/\?\w]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::Rule', 
                                   $1, 
                                   { empty_is_null => ['value'], 
                                     defaults => {reduce=>1},
                                     edit => $self->{edit}
                                   }
            ) if /rule_browser([\/\?\w]*)$/;

        return $self->impact_network() if /impact_network$/;
        return $self->object_editor('SmartSea::Schema::Result::Dataset',
                                   $1, 
                                   { empty_is_null => [qw/contact desc attribution disclaimer path/],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /datasets([\/\?\w]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::Activity2Pressure',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /activity2pressure([\/\?\w]*)$/;

        return $self->object_editor('SmartSea::Schema::Result::Impact',
                                   $1, 
                                   { empty_is_null => [qw//],
                                     defaults => {},
                                     edit => $self->{edit}
                                   }
            ) if /impact([\/\?\w]*)$/;

        return $self->pressure_table($1) if /pressure_table([\/\?\w]*)$/;
        last;
    }
    my $uri = $self->{uri};
    $uri .= '/' unless $uri =~ /\/$/;
    my @l;
    push @l, (
        [li => a(link => 'uses', url => $uri.'uses')],
        [li => a(link => 'plans', url  => $uri.'plans')],
        [li => a(link => 'plan browser', url => $uri.'plan_browser')],
        [li => a(link => 'use browser', url => $uri.'use_browser')],
        [li => a(link => 'activity browser', url => $uri.'activity_browser')],
        [li => a(link => 'ecosystem component browser', url => $uri.'ec_browser')],
        [li => a(link => 'rule browser', url  => $uri.'rule_browser')],
        [li => a(link => 'impact_network', url  => $uri.'impact_network')],
        [li => a(link => 'datasets', url  => $uri.'datasets')],
        [li => a(link => 'activity -> pressure links', url  => $uri.'activity2pressure')],
        [li => a(link => 'impacts', url  => $uri.'impact')],
        [li => a(link => 'pressure table', url  => $uri.'pressure_table')]
    );
    return html200(SmartSea::HTML->new(html => [body => [ul => \@l]])->html);
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
    my ($self, $oids) = @_;
    my $uri = $self->{uri};
    $uri =~ s/$oids$//;
    my @oids = split /\//, $oids;
    shift @oids;
    my $plan_id = shift @oids;
    my $schema = $self->{schema};
    my @plans;
    my $search = defined $plan_id ? {id => $plan_id}: undef;
    for my $plan ($schema->resultset('Plan')->search($search, {order_by => 'title'})) {
        my @uses;
        for my $use ($plan->uses(undef, {order_by => 'id'})) {
            my @layers;
            for my $layer ($use->layers(undef, {order_by => 'id'})) {
                my @rules;
                for my $rule ($schema->resultset('Rule')->search({
                    -and => [
                         -or => [plan => $plan->id, plan => {'=' => undef}],
                         use => $use->id,
                         layer => $layer->id
                        ]
                                                                 })) {
                    push @rules, {title => $rule->as_text, id => $rule->id, active => JSON::true};
                }
                push @layers, {title => $layer->title, id => $layer->id, rules => \@rules};
            }
            push @uses, {title => $use->title, id => $use->id, layers => \@layers};
        }
        push @plans, {title => $plan->title, id => $plan->id, uses => \@uses};
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

sub object_editor {
    my ($self, $class, $oids, $config) = @_;

    # oids is what's after the base in URI, 
    # a list of object ids separated by / and possibly /new or ?edit in the end
    # DBIx Class understands undef as NULL
    # config: delete => value-in-the-delete-button (default is Delete)
    #         store => value-in-the-store-button (default is Store)
    #         empty_is_null => parameters will be converted to undef if empty strings
    #         defaults => parameters will be set to the value unless in self->parameters
    # 'NULL' parameters will be converted to undef, 

    my $uri = $self->{uri};
    $uri =~ s/$oids$//;
    my @oids = split /\//, $oids;
    shift @oids;
    my $oid = shift(@oids) // '';
    #say STDERR "$uri, $oids, $oid";
    
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

    if ($request eq $config->{delete} and $config->{edit}) {

        eval {
            $rs->single({ id => $parameters{id} })->delete;
        };
        if ($@) {
            # if not ok, signal error
            push @body, [p => 'Something went wrong!'], [p => 'Error is: '.$@];
        }

    } elsif ($request eq $config->{store} and $config->{edit}) {

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
        
    } elsif ($oid eq 'new' and $config->{edit}) {

        my $body = [];
        push @$body, [form => { action => $uri, method => 'POST' },
                      $class->HTML_form($self, \%parameters)];
        return html200(SmartSea::HTML->new(html => [body => $body])->html);

    } elsif ($oid =~ /edit/ and $config->{edit}) {

        ($oid) = $oid =~ /(\d+)/;
        my $obj = $rs->single({ id => $oid });
        return return_400 unless defined $obj;
        $uri =~ s/\?edit$//;
        my $body = [form => { action => $uri, method => 'POST' },
                    $obj->HTML_form($self)];
        return html200(SmartSea::HTML->new(html => [body => $body])->html);
        
    } elsif ($oid =~ /\d+/) {

        ($oid) = $oid =~ /(\d+)/;
        my $obj = $rs->single({ id => $oid });
        return return_400 unless defined $obj;
        my $body = $obj->HTML_text($self, \@oids);
        $body = [form => { action => $uri, method => 'POST' }, $body] if $config->{edit};
        return html200(SmartSea::HTML->new(html => [body => $body])->html);
        
    }

    push @body, @{$class->HTML_list([$rs->all], $uri, $config->{edit})};
    return html200(SmartSea::HTML->new(html => [body => \@body])->html);

}

sub pressure_table {
    my ($self, $x) = @_;
    my %edits;
    $edits{aps} = $self->{schema}->resultset('Activity2Pressure');
    $edits{impacts} = $self->{schema}->resultset('Impact');
    my $pressures = $self->{schema}->resultset('Pressure');
    my %id;
    my %pressures;
    my %cats;
    for my $pressure ($pressures->all) {
        $pressures{$pressure->title} = $pressure->order;
        $id{pressures}{$pressure->title} = $pressure->id;
        $cats{$pressure->title} = $pressure->category->title;
    }
    my $activities = $self->{schema}->resultset('Activity');
    my %activities;
    my %title;
    for my $activity ($activities->all) {
        $activities{$activity->title} = $activity->order;
        $id{activities}{$activity->title} = $activity->id;
        $title{$activity->title} = $activity->title.'('.$activity->order.')';
    }
    my $components = $self->{schema}->resultset('EcosystemComponent');
    my %components;
    for my $component ($components->all) {
        $components{$component->title} = $component->order;
        $id{components}{$component->title} = $component->id;
    }

    for my $pressure ($pressures->all) {
        for my $activity ($activities->all) {
            my $key = 'range_'.$pressure->id.'_'.$activity->id;
            $title{$key} = $pressure->title.' '.$activity->title;

            my $ap = $edits{aps}->single({pressure => $pressure->id, activity => $activity->id});
            $title{$pressure->title}{$activity->title} = $activity->title; #.' '.$ap->id if $ap;
        }
    }

    my %attrs;
    my %ranges;
    for my $ap ($edits{aps}->all) {
        $ranges{$ap->pressure->title}{$ap->activity->title} = $ap->range;
        my $key = 'range_'.$ap->pressure->id.'_'.$ap->activity->id;
        $attrs{$key} = $ap->range;
        $id{activity2pressure}{$ap->pressure->title}{$ap->activity->title} = $ap->id;
    }
    my %impacts;
    for my $impact ($edits{impacts}->all) {
        my $ap = $impact->activity2pressure;
        my $p = $ap->pressure;
        my $a = $ap->activity;
        my $e = $impact->ecosystem_component;
        my $title = $p->title.'+'.$a->title.' -> '.$e->title;
        $impacts{$p->title}{$a->title}{$e->title} = [$impact->strength,$impact->belief];
        my $key = 'strength_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->strength;
        $title{$key} = $title;
        $key = 'belief_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->belief;
        $title{$key} = $title;
    }
    
    #for my $key (sort $self->{parameters}->keys) {
    #    say STDERR "$key $self->{parameters}{$key}";
    #}

    my @error = ();

    my $submit = $self->{parameters}{submit} // '';
    if ($submit eq 'Commit') {
        for my $key ($self->{parameters}->keys) {
            next if $key eq 'submit';
            my $value = $self->{parameters}{$key};
            my ($attr, $one, $two) = $key =~ /([a-w]+)_(\d+)_(\d+)/;

            my %single;
            my %params;
            my $edits;
            if ($attr eq 'range') {
                next if $value eq '0';
                %single = (pressure => $one, activity => $two);
                %params = (pressure => $one, activity => $two, $attr => $value);
                $edits = $edits{aps};
            } else {
                next if $value eq '-1';
                %single = (activity2pressure => $one, ecosystem_component => $two);
                %params = (activity2pressure => $one, ecosystem_component => $two, $attr => $value);
                if (!exists($attrs{$key})) {
                    if ($attr eq 'belief') {
                        $params{strength} = 0;
                    } else {
                        $params{belief} = 0;
                    }
                }
                $edits = $edits{impacts};
            }
            #say STDERR "key = $key, value = $value";
            if (exists($attrs{$key})) {
                if ($attrs{$key} ne $value) {
                    say STDERR "change $key from $attrs{$key} to $value";
                    my $obj = $edits->single(\%single);
                    eval {
                        $obj->update(\%params);
                    };
                }
            } else {
                say STDERR "insert $key as $value";
                eval {
                    $edits->create(\%params);
                };
            }

            if ($@) {
                # if not ok, signal error
                push @error, (
                    [p => 'Something went wrong!'], 
                    [p => 'Error is: '.$@]
                );
                undef $@;
            }

        }

        for my $ap ($edits{aps}->all) {
            $ranges{$ap->pressure->title}{$ap->activity->title} = $ap->range;
        }
        for my $impact ($edits{impacts}->all) {
            my $ap = $impact->activity2pressure;
            my $p = $ap->pressure;
            my $a = $ap->activity;
            my $e = $impact->ecosystem_component;
            $impacts{$p->title}{$a->title}{$e->title} = [$impact->strength,$impact->belief];
        }
    }
    
    my @rows;

    my @components = sort {$components{$a} <=> $components{$b}} keys %components;
    my @headers = ();
    my @tr = ([th => {colspan => 3}, '']);
    for my $component (@components) {
        push @tr, [th => {colspan => 2}, $component];
    }
    push @rows, [tr => [@tr]];

    @headers = ('Pressure', 'Activity', 'Range');
    for (@components) {
        push @headers, qw/Impact Belief/;
    }
    @tr = ();
    for my $h (@headers) {
        push @tr, [th => $h];
    }
    push @rows, [tr => [@tr]];

    my $c = 0;
    my $cat = '';
    for my $pressure (sort {$pressures{$a} <=> $pressures{$b}} keys %pressures) {
        next unless $pressures{$pressure};
        my @activities;
        for my $activity (sort {$activities{$a} <=> $activities{$b}} keys %activities) {
            next unless exists $ranges{$pressure}{$activity};
            my $range = $ranges{$pressure}{$activity} // 0;
            next if $range < 0;
            push @activities, $activity;
        }
        my @td = ([td => {rowspan => $#activities+1}, $pressure]);
        for my $activity (@activities) {
            my $color = $c ? '#cccccc' : '#ffffff';
            push @td, [td => {bgcolor=>$color}, $title{$pressure}{$activity}];

            my $idp = $id{pressures}{$pressure};
            my $ida = $id{activities}{$activity};
            my $idap = $id{activity2pressure}{$pressure}{$activity};

            my $range = $ranges{$pressure}{$activity} // 0;
            $range = text_input(
                name => 'range_'.$idp.'_'.$ida,
                size => 1,
                value => $range
                ) if $self->{edit};
            push @td, [td => {bgcolor=>$color}, $range];

            $color = $c ? '#00ffff' : '#ffffff';
            my $color2 = $c ? '#7fffd4' : '#ffffff';

            for my $component (@components) {
                my $idc = $id{components}{$component};
                my $impact = $impacts{$pressure}{$activity}{$component} // [-1,-1];
                $impact = [text_input(
                               name => 'strength_'.$idap.'_'.$idc,
                               size => 1,
                               value => $impact->[0]
                           ),
                           text_input(
                               name => 'belief_'.$idap.'_'.$idc,
                               size => 1,
                               value => $impact->[1]
                           )] if $self->{edit};
                push @td, ([td => {bgcolor=>$color}, $impact->[0]],[td => {bgcolor=>$color2}, $impact->[1]]);
            }

            if ($cat ne $cats{$pressure}) {
                $cat = $cats{$pressure};
                my @c = ([td => $cat]);
                for (1..$#td) {
                    push @c, [td => ''];
                }
                push @rows, [tr => \@c];
            }

            push @rows, [tr => [@td]];
            @td = ();
            $c = !$c; 
        }
    }

    my @a = ([a => {href => $self->{uri}}, 'reload'],
             [1 => "&nbsp;&nbsp;"]);
    push @a, [input => {type => 'submit', name => 'submit', value => 'Commit'}] if $self->{edit};
    push @a, [table => {border => 1}, \@rows];
    push @a, [input => {type => 'submit', name => 'submit', value => 'Commit'}] if $self->{edit};
    
    my @body = (@error, [ form => {action => $self->{uri}, method => 'POST'}, \@a ]);

    return html200(SmartSea::HTML->new(html => [body => \@body])->html);
}

1;
