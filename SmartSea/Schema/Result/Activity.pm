package SmartSea::Schema::Result::Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my %attributes = (
    name =>  { i => 1,  input => 'text',  size => 20 },
    ordr =>  { i => 2,  input => 'text',  size => 10 },
    );

__PACKAGE__->table('activities');
__PACKAGE__->add_columns(qw/ id ordr name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'activity');
__PACKAGE__->many_to_many(pressures => 'activity2pressure', 'pressure');
__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(uses => 'use2activity', 'activity');

sub attributes {
    return \%attributes;
}

sub relationship_methods {
    return { pressures => [pressure => 0] };
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %data;
    my %li;
    my %has;
    for my $act (@$objs) {
        my $a = $act->name;
        my $id = $act->id;
        $has{$id} = 1;
        $li{act}{$a} = item([b => $a], "activity:$id", %args, ref => 'this activity');
        my @refs = $act->activity2pressure;
        for my $ref (@refs) {
            my $pressure = $ref->pressure;
            my $p = $pressure->name;
            $data{$a}{$p} = 1;
            my $id = 'activity:'.$act->id.'/'.$pressure->id;
            $li{$a}{$p} = item($p, $id, %args, action => 'None');
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

    if ($args{edit} && $args{use} && !$args{plan}) {
        my @objs;
        for my $obj ($args{schema}->resultset('Activity')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        if (@objs) {
            my $drop_down = drop_down(name => 'activity', objs => \@objs);
            push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'activity')]];
        }
    }

    my $ret = [ul => \@li];
    return [ ul => [ [li => 'Activities'], $ret ]] if $args{named_list};
    return [ li => [ [0 => 'Activities:'], $ret ]] if $args{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    push @l, [li => 'Activity'] unless $args{use};
    for my $a (qw/id name/) {
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
    $args{activity} = $self->id;
    if (my $oid = shift @{$args{oids}}) {
        push @l, $self->pressures->single({'pressure.id' => $oid})->HTML_div({}, %args, named_item => 1);
    } else {
        $args{action} = $args{use} ? 'None' : 'Remove';
        push @l, SmartSea::Schema::Result::Pressure->HTML_list([$self->pressures], %args, named_item => 1);
    }
    my $ret = [ul => \@l];
    return [ li => [0 => 'Activity:'], $ret ] if $args{named_item};
    return [ div => $attributes, $ret ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    my @form;

    my $button_value;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Activity')) {
        for my $key (qw/name/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
        $button_value = 'Store';
    } else {
        $button_value = 'Create';
    }

    my $name = text_input(
        name => 'name',
        size => 15,
        value => $values->{name} // ''
    );

    push @form, (
        [ p => [[1 => 'name: '],$name] ],
        button(value => $button_value)
    );

    return [form => $attributes, @form];
}

1;
