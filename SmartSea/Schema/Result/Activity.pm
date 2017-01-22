package SmartSea::Schema::Result::Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.activities');
__PACKAGE__->add_columns(qw/ id order title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'activity');
__PACKAGE__->many_to_many(pressures => 'activity2pressure', 'pressure');
__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');

sub HTML_list {
    my (undef, $objs, %arg) = @_;
    my ($uri, $edit) = ($arg{uri}, $arg{edit});
    my %data;
    my %li;
    my %has;
    for my $act (@$objs) {
        my $a = $act->title;
        my $id = $act->id;
        $has{$id} = 1;
        $li{act}{$a} = item([b => $a], "activity:$id", %arg, ref => 'this activity');
        my @refs = $act->activity2pressure;
        for my $ref (@refs) {
            my $pressure = $ref->pressure;
            my $p = $pressure->title;
            $data{$a}{$p} = 1;
            my $id = $act->id.'/'.$pressure->id;
            $li{$a}{$p} = item($p, $id, %arg, ref => 'this pressure from this activity');
        }
    }
    my @li;
    for my $act (sort keys %{$li{act}}) {
        my @l;
        for my $pressure (sort keys %{$data{$act}}) {
            push @l, [li => $li{$act}{$pressure}];
        }
        my @item = @{$li{act}{$act}};
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }

    if ($edit) {
        my @objs;
        for my $obj ($arg{schema}->resultset('Activity')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        if (@objs) {
            my $drop_down = drop_down(name => 'activity', objs => \@objs);
            push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'activity')]];
        }
    }

    my $ret = [ul => \@li];
    return [ ul => [ [li => 'Activities'], $ret ]] if $arg{named_list};
    return [ li => [ [0 => 'Activities'], $ret ]] if $arg{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, $oids, %arg) = @_;
    my @l = ([li => 'Activity']);
    for my $a (qw/id title/) {
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
    my $associated_class = 'SmartSea::Schema::Result::Pressure';
    if (@$oids) {
        my $oid = shift @$oids;
        if (not defined $oid) {
            push @div, $associated_class->HTML_list([$self->pressures], %arg, activity => $self->id);
            push @div, [div => 'add here a form for adding an existing pressure into this activity'];
        } else {
            push @div, $self->pressures->single({'pressure.id' => $oid})->HTML_div({}, $oids, %arg);
        }
    } else {
        push @div, $associated_class->HTML_list([$self->pressures], %arg, activity => $self->id);
    }
    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $values, %arg) = @_;

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Activity')) {
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
