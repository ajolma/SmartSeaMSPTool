package SmartSea::Schema::Result::UseClass2Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('use_class2activity');
__PACKAGE__->add_columns(qw/ id use_class activity /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(use_class => 'SmartSea::Schema::Result::UseClass');
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');

sub attributes {
    return {
        activity => {i => 1, input => 'lookup', source => 'Activity'},
        use_class => {i => 2, input => 'lookup', source => 'UseClass'}
    };
}

sub order_by {
    return {-asc => 'id'};
}

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {} unless $parent;
    return {use_class => $parent->id, activity => $parameters->{activity}};
}

sub name {
    my $self = shift;
    return $self->use_class->name.' -> '.$self->activity->name;
}

1;
