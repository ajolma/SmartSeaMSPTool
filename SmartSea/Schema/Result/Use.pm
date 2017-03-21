package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my %attributes = (
    name =>            { i => 1,  input => 'text',    size => 20 }
    );

__PACKAGE__->table('uses');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'use');
__PACKAGE__->many_to_many(plans => 'plan2use', 'plan');

__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');

sub attributes {
    return \%attributes;
}

sub relationship_methods {
    my $self = shift;
    return {
        activities => 0,
        layers => 1
    };
}

sub layers {
    my ($self, $oids) = @_;
    my @layers = ();
    # find the plan from oids
    my $plan;
    for my $oid (@$oids) {
        my ($class, $id) = split /:/, $oid;
        if ($class eq 'plan') {
            $plan = $id;
            last;
        }
    }
    for my $p2u ($self->plan2use->search({plan => $plan})->all) {
        for my $layer ($p2u->layers) {
            push @layers, $layer;
        }
    }
    return sort {$a->name cmp $b->name} @layers;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %li;
    my %has;
    for my $use (@$objs) {
        my $u = $use->name;
        $has{$use->id} = 1;
        my $ref = 'this use';
        $li{$u}{0} = item([b => $u], 'use:'.$use->id, %args, ref => $ref);
        if ($args{plan}) {
            my $plan2use = $args{schema}->
                resultset('Plan2Use')->
                single({plan => $args{plan}, use => $use->id});
            for my $layer ($plan2use->layers) {
                my $a = $layer->layer_class->name;
                my $id = $use->id.'/layer:'.$layer->id;
                $li{$u}{layer}{$a} = item($a, $id, %args, action => 'None');
            }
        }
        for my $activity ($use->activities) {
            my $a = $activity->name;
            my $id = $use->id.'/activity:'.$activity->id;
            $li{$u}{activity}{$a} = item($a, $id, %args, action => 'None');
        }
    }
    my @li;
    for my $use (sort keys %li) {
        my @l;
        for my $layer (sort keys %{$li{$use}{layer}}) {
            next unless $layer;
            push @l, [li => $li{$use}{layer}{$layer}];
        }
        my @a;
        for my $activity (sort keys %{$li{$use}{activity}}) {
            next unless $activity;
            push @a, [li => $li{$use}{activity}{$activity}];
        }
        my @item = @{$li{$use}{0}};
        my @s;
        push @s, [li => [[0=>'Layers'],[ul=>\@l]]] if @l;
        push @s, [li => [[0=>'Activities'],[ul=>\@a]]] if @a;
        push @item, [ul => \@s];
        push @li, [li => \@item];
    }

    if ($args{edit}) {
        if ($args{plan}) {
            my @objs;
            for my $obj ($args{schema}->resultset('Use')->all) {
                next if $has{$obj->id};
                push @objs, $obj;
            }
            if (@objs) {
                my $drop_down = drop_down(name => 'use', objs => \@objs);
                push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'use')]];
            }
        } else {
            my $name = text_input(name => 'name');
            push @li, [li => [$name, 
                              [0 => ' '],
                              button(value => 'Create', name => 'use')]];
        }
    }

    my $ret = [ul => \@li];
    return [ li => [0 => 'Uses:'], $ret ] if $args{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my $error;
    my @l;
    push @l, ([li => [b => 'Use']]) unless $args{plan};
    for my $a (qw/id name /) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/name id data/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    if (my $oid = shift @{$args{oids}}) {
        $args{action} = 'None';
        if ($oid =~ /layer/) {
            $oid =~ s/layer://;
            if ($args{plan}) {
                my $plan2use = $args{schema}->
                    resultset('Plan2Use')->
                    single({plan => $args{plan}, use => $self->id});
                $args{plan2use} = $plan2use->id;
                push @l, $plan2use->
                    layers->single({id => $oid})->
                    HTML_div({}, %args, named_item => 1);
            }
        } elsif ($oid =~ /activity/) {
            $oid =~ s/activity://;
            $args{use} = $self->id;
            push @l, $self->activities->single({'activity.id' => $oid})->HTML_div({}, %args, named_item => 1);
        }
    } else {
        # parameters for remove request: remove => layer:n
        # parameters for add request: layer => n
        if ($args{parameters}{request} eq 'add') {
            if ($args{parameters}{add} eq 'layer') {
                if ($args{plan}) {
                    my $plan2use = $args{schema}->
                        resultset('Plan2Use')->
                        single({plan => $args{plan}, use => $self->id});
                    my $layer = $args{schema}->resultset('LayerClass')->single({ id => $args{parameters}{layer} });
                    eval {
                        $plan2use->add_to_layers($layer);
                    };
                    $error = $@;
                    say STDERR $@ if $@;
                }
            } elsif ($args{parameters}{add} eq 'activity') {
                my $activity = $args{schema}->resultset('Activity')->single({ id => $args{parameters}{activity} });
                eval {
                    $self->add_to_activities($activity);
                };
                $error = $@;
                say STDERR $@ if $@;
            }
        } elsif ($args{parameters}{request} eq 'remove') {
            my $remove = $args{parameters}{remove};
            if ($remove =~ /layer/) {
                $remove =~ s/layer://;
                if ($args{plan}) {
                    my $plan2use = $args{schema}->
                        resultset('Plan2Use')->
                        single({plan => $args{plan}, use => $self->id});
                    my $layer = $args{schema}->resultset('LayerClass')->single({ id => $remove });
                    eval {
                        $plan2use->remove_from_layers($layer);
                    };
                    $error = $@;
                    say STDERR $@ if $@;
                }
            } elsif ($remove =~ /activity/) {
                $remove =~ s/activity://;
                my $activity = $args{schema}->resultset('Activity')->single({ id => $remove });
                eval {
                    $self->remove_from_activities($activity);
                };
                $error = $@;
                say STDERR $@ if $@;
            }
        }
        $args{action} = 'Remove';
        if ($args{plan}) {
            my $plan2use = $args{schema}->
                resultset('Plan2Use')->
                single({plan => $args{plan}, use => $self->id});
            push @l, SmartSea::Schema::Result::Layer->
                HTML_list([$plan2use->layers], %args, named_item => 1);
            $args{action} = 'None'; # activities are added/removed only when uses are edited
        }
        $args{use} = $self->id;
        push @l, SmartSea::Schema::Result::Activity->HTML_list([$self->activities], %args, named_item => '1');
    }

    my @content;
    push @content, [0 => $error] if $error;
    push @content, [ul => \@l];

    return [ li => [0 => 'Use:'], @content ] if $args{named_item};
    return [ div => $attributes, @content ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    if (@{$args{oids}}) {
        my $oid = shift @{$args{oids}};
        if ($oid =~ /layer/) {
            $oid =~ s/layer://;
            if ($args{plan}) {
                my $plan2use = $args{schema}->
                    resultset('Plan2Use')->
                    single({plan => $args{plan}, use => $self->id});
                $args{plan2use} = $plan2use->id;
                return $plan2use->layers->single({layer => $oid})->HTML_form($attributes, undef, %args);
            }
        } elsif ($oid =~ /activity/) {
            $oid =~ s/activity://;
            return $self->activities->single({id => $oid})->HTML_form($attributes, undef, %args);
        }
    }

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Use')) {
        for my $key (qw/name/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $name = text_input(
        name => 'name',
        size => 15,
        value => $values->{name} // ''
    );

    push @form, (
        [ p => [[1 => 'name: '],$name] ],
        button(value => "Store")
    );

    return [form => $attributes, @form];
}

1;
