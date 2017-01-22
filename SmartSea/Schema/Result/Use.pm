package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.uses');
__PACKAGE__->add_columns(qw/ id title current_allocation /);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'use');
__PACKAGE__->many_to_many(plans => 'plan2use', 'plan');

__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');

__PACKAGE__->belongs_to(current_allocation => 'SmartSea::Schema::Result::Dataset');

sub HTML_list {
    my (undef, $objs, %arg) = @_;
    my %li;
    for my $use (@$objs) {
        my $u = $use->title;
        $li{$u}{0} = item([b => $u], $use->id, %arg, ref => 'this use');
        if ($arg{plan}) {
            my $plan2use = $arg{schema}->
                resultset('Plan2Use')->
                single({plan => $arg{plan}, use => $use->id});
            for my $layer ($plan2use->layers) {
                my $a = $layer->title;
                my $id = $use->id.'/layer:'.$layer->id;
                $li{$u}{layer}{$a} = item($a, $id, %arg, action => 'None', ref => 'this layer from this plan+use');
            }
        }
        for my $activity ($use->activities) {
            my $a = $activity->title;
            my $id = $use->id.'/activity:'.$activity->id;
            $li{$u}{activity}{$a} = item($a, $id, %arg, action => 'None', ref => 'this activity from this use');
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
        my @s1 = (li => [[0=>'Layers'],[ul=>\@l]]);
        my @s2 = (li => [[0=>'Activities'],[ul=>\@a]]);
        my @s = (\@s1, \@s2);
        push @item, [ul => \@s];
        push @li, [li => \@item];
    }
    my $action = $arg{action} eq 'Delete' ? 'create' : 'add';
    push @li, [li => a(link => "$action use", url => $arg{uri}.'/new')] if $arg{edit};
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $oids, %arg) = @_;
    my @l = ([li => [b => 'Use']]);
    for my $a (qw/id title current_allocation/) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/title name data op id/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    my @div = ([ul => \@l]);
    $arg{action} = 'Remove';
    if (@$oids) {
        my $oid = shift @$oids;
        if ($oid =~ /layer/) {
            $oid =~ s/layer://;
            if ($arg{plan}) {
                my $plan2use = $arg{schema}->
                    resultset('Plan2Use')->
                    single({plan => $arg{plan}, use => $self->id});
                $arg{plan2use} = $plan2use->id;
                push @div, $plan2use->layers->single({'layer.id' => $oid})->HTML_div({}, $oids, %arg);
            }
        } elsif ($oid =~ /activity/) {
            $oid =~ s/activity://;
            push @div, $self->activities->single({'activity.id' => $oid})->HTML_div({}, $oids, %arg);
        }
    } else {
        # parameters for remove request: remove => layer:n
        # parameters for add request: layer => n
        if ($arg{parameters}{request} eq 'add') {
            if ($arg{parameters}{add} eq 'layer') {
                if ($arg{plan}) {
                    my $plan2use = $arg{schema}->
                        resultset('Plan2Use')->
                        single({plan => $arg{plan}, use => $self->id});
                    my $layer = $arg{schema}->resultset('Layer')->single({ id => $arg{parameters}{layer} });
                    $plan2use->add_to_layers($layer);
                }
            } elsif ($arg{parameters}{add} eq 'activity') {
                my $activity = $arg{schema}->resultset('Activity')->single({ id => $arg{parameters}{activity} });
                $self->add_to_activities($activity);
            }
        } elsif ($arg{parameters}{request} eq 'remove') {
            my $remove = $arg{parameters}{remove};
            if ($remove =~ /layer/) {
                $remove =~ s/layer://;
                if ($arg{plan}) {
                    my $plan2use = $arg{schema}->
                        resultset('Plan2Use')->
                        single({plan => $arg{plan}, use => $self->id});
                    my $layer = $arg{schema}->resultset('Layer')->single({ id => $remove });
                    $plan2use->remove_from_layers($layer);
                }
            } elsif ($remove =~ /activity/) {
                $remove =~ s/activity://;
                my $activity = $arg{schema}->resultset('Activity')->single({ id => $remove });
                $self->remove_from_activities($activity);
            }
        }
        my @ul;
        if ($arg{plan}) {
            my $plan2use = $arg{schema}->
                resultset('Plan2Use')->
                single({plan => $arg{plan}, use => $self->id});
            push @ul, SmartSea::Schema::Result::Layer->HTML_list([$plan2use->layers], %arg, named_item => 1);
        }
        push @ul, SmartSea::Schema::Result::Activity->HTML_list([$self->activities], %arg, named_item => 1);
        push @div, [ul => \@ul];
    }
    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $values, $oids, %arg) = @_;

    if (@$oids) {
        my $oid = shift @$oids;
        if ($oid =~ /layer/) {
            $oid =~ s/layer://;
            return $self->layers->single({id => $oid})->HTML_form($attributes, undef, $oids, %arg);
        } elsif ($oid =~ /activity/) {
            $oid =~ s/activity://;
            return $self->activities->single({id => $oid})->HTML_form($attributes, undef, $oids, %arg);
        }
    }

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Use')) {
        for my $key (qw/title/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $title = text_input(
        name => 'title',
        size => 15,
        value => $values->{title} // ''
    );

    push @form, (
        [ p => [[1 => 'title: '],$title] ],
        button(value => "Store")
    );

    return [form => $attributes, @form];
}

1;
