package SmartSea::Schema::Result::Activity2Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

__PACKAGE__->table('activity2pressure');
__PACKAGE__->add_columns(qw/ id activity pressure_class range /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');
__PACKAGE__->belongs_to(pressure_class => 'SmartSea::Schema::Result::PressureClass');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'activity2pressure');

sub order_by {
    return {-asc => 'id'};
}

sub attributes {
    return {range => {input => 'text'}}; # todo: show range as real units
}

sub class_name {
    return 'Pressure';
}

sub children_listers {
    return { impacts => [impact => 0] }; # todo: activity2pressure here
}

sub for_child_form {
    my ($self, $kind, $children, $args) = @_;
    if ($kind eq 'impacts') {
        my %has;
        for my $obj (@$children) {
            $has{$obj->ecosystem_component->id} = 1;
        }
        my @objs;
        for my $obj ($args->{schema}->resultset('EcosystemComponent')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        return 0 if @objs == 0; # all ecosystem components have already an impact
        return drop_down(name => 'ecosystem_component', objs => \@objs);
    }
}

sub name {
    my $self = shift;
    return $self->activity->name.' <-> '.$self->pressure_class->name;
}

sub impacts_list {
    my ($self) = @_;
    my @impacts;
    for my $impact (sort {$b->strength*10+$b->belief <=> $a->strength*10+$a->belief} $self->impacts) {
        my $ec = $impact->ecosystem_component;
        my $c = $ec->name;
        my $strength = $strength{$impact->strength};
        my $belief = $belief{$impact->belief};
        push @impacts, [li => "impact on $c is $strength, $belief."];
    }
    return \@impacts;
}

1;
