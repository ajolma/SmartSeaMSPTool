package SmartSea::Schema::ResultSet::Pressure;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub table {
    my ($self, $impact_rs, $pressure_class_rs, $activity_rs, $ecosystem_component_rs, $parameters, $edit) = @_;
    my %id;
    my %pressure_classes;
    my %cats;
    for my $pressure_class ($pressure_class_rs->all) {
        $pressure_classes{$pressure_class->name} = $pressure_class->ordr;
        $id{pressure_classes}{$pressure_class->name} = $pressure_class->id;
        $cats{$pressure_class->name} = $pressure_class->category->name;
    }
    my %activities;
    my %name;
    for my $activity ($activity_rs->all) {
        $activities{$activity->name} = $activity->ordr;
        $id{activities}{$activity->name} = $activity->id;
        $name{$activity->name} = $activity->name.'('.$activity->ordr.')';
    }
    my %components;
    for my $component ($ecosystem_component_rs->all) {
        $components{$component->name} = $component->id;
        $id{components}{$component->name} = $component->id;
    }

    for my $pressure_class ($pressure_class_rs->all) {
        for my $activity ($activity_rs->all) {
            my $key = 'range_'.$pressure_class->id.'_'.$activity->id;
            $name{$key} = $pressure_class->name.' '.$activity->name;

            my $ap = $self->single({pressure_class => $pressure_class->id, activity => $activity->id});
            $name{$pressure_class->name}{$activity->name} = $activity->name; #.' '.$ap->id if $ap;
        }
    }

    my %attrs;
    my %ranges;
    for my $ap ($self->all) {
        $ranges{$ap->pressure_class->name}{$ap->activity->name} = $ap->range;
        my $key = 'range_'.$ap->pressure_class->id.'_'.$ap->activity->id;
        $attrs{$key} = $ap->range;
        $id{pressure}{$ap->pressure_class->name}{$ap->activity->name} = $ap->id;
    }
    my %impacts;
    for my $impact ($impact_rs->all) {
        my $ap = $impact->pressure;
        my $p = $ap->pressure_class;
        my $a = $ap->activity;
        my $e = $impact->ecosystem_component;
        my $name = $p->name.'+'.$a->name.' -> '.$e->name;
        $impacts{$p->name}{$a->name}{$e->name} = [$impact->strength,$impact->belief];
        my $key = 'strength_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->strength;
        $name{$key} = $name;
        $key = 'belief_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->belief;
        $name{$key} = $name;
    }
    
    my @error = ();

    my $submit = $parameters->{submit} // '';
    if ($submit eq 'Commit') {
        for my $key ($parameters->keys) {
            next if $key eq 'submit';
            my $value = $parameters->{$key};
            my ($attr, $one, $two) = $key =~ /([a-w]+)_(\d+)_(\d+)/;

            my %single;
            my %params;
            my $edits;
            if ($attr eq 'range') {
                next if $value eq '0';
                %single = (pressure_class => $one, activity => $two);
                %params = (pressure_class => $one, activity => $two, $attr => $value);
                $edits = $self;
            } else {
                next if $value eq '-1';
                %single = (pressure => $one, ecosystem_component => $two);
                %params = (pressure => $one, ecosystem_component => $two, $attr => $value);
                if (!exists($attrs{$key})) {
                    if ($attr eq 'belief') {
                        $params{strength} = 0;
                    } else {
                        $params{belief} = 0;
                    }
                }
                $edits = $impact_rs;
            }
            #say STDERR "key = $key, value = $value";
            if (exists($attrs{$key})) {
                if ($attrs{$key} ne $value) {
                    say STDERR "change $key from $attrs{$key} to $value" if $self->{debug};
                    my $obj = $edits->single(\%single);
                    eval {
                        $obj->update(\%params);
                    };
                }
            } else {
                say STDERR "insert $key as $value" if $self->{debug};
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

        for my $ap ($self->all) {
            $ranges{$ap->pressure_class->name}{$ap->activity->name} = $ap->range;
        }
        for my $impact ($impact_rs->all) {
            my $ap = $impact->pressure;
            my $p = $ap->pressure_class;
            my $a = $ap->activity;
            my $e = $impact->ecosystem_component;
            $impacts{$p->name}{$a->name}{$e->name} = [$impact->strength,$impact->belief];
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
    for my $pressure_class (sort {$pressure_classes{$a} <=> $pressure_classes{$b}} keys %pressure_classes) {
        next unless $pressure_classes{$pressure_class};
        my @activities;
        for my $activity (sort {$activities{$a} <=> $activities{$b}} keys %activities) {
            next unless exists $ranges{$pressure_class}{$activity};
            my $range = $ranges{$pressure_class}{$activity} // 0;
            next if $range < 0;
            push @activities, $activity;
        }
        my @td = ([td => {rowspan => $#activities+1}, $pressure_class]);
        for my $activity (@activities) {
            my $color = $c ? '#cccccc' : '#ffffff';
            push @td, [td => {bgcolor=>$color}, $name{$pressure_class}{$activity}];

            my $idp = $id{pressure_classes}{$pressure_class};
            my $ida = $id{activities}{$activity};
            my $idap = $id{pressure}{$pressure_class}{$activity};

            my $range = $ranges{$pressure_class}{$activity} // 0;
            $range = text_input(
                name => 'range_'.$idp.'_'.$ida,
                size => 1,
                value => $range
                ) if $edit;
            push @td, [td => {bgcolor=>$color}, $range];

            $color = $c ? '#00ffff' : '#ffffff';
            my $color2 = $c ? '#7fffd4' : '#ffffff';

            for my $component (@components) {
                my $idc = $id{components}{$component};
                my $impact = $impacts{$pressure_class}{$activity}{$component} // [-1,-1];
                $impact = [text_input(
                               name => 'strength_'.$idap.'_'.$idc,
                               size => 1,
                               value => $impact->[0]
                           ),
                           text_input(
                               name => 'belief_'.$idap.'_'.$idc,
                               size => 1,
                               value => $impact->[1]
                           )] if $edit;
                push @td, ([td => {bgcolor=>$color}, $impact->[0]],[td => {bgcolor=>$color2}, $impact->[1]]);
            }

            if ($cat ne $cats{$pressure_class}) {
                $cat = $cats{$pressure_class};
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
    push @a, [input => {type => 'submit', name => 'submit', value => 'Commit'}] if $edit;
    push @a, [table => {border => 1}, \@rows];
    push @a, [input => {type => 'submit', name => 'submit', value => 'Commit'}] if $edit;
    
    return [@error, [ form => {action => $self->{uri}, method => 'POST'}, \@a ]];
}


1;
