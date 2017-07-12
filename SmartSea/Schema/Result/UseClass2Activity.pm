package SmartSea::Schema::Result::UseClass2Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

my @columns = (
    id   => {},
    activity => {is_foreign_key => 1, source => 'Activity', not_null => 1},
    use_class => {is_foreign_key => 1, source => 'UseClass', not_null => 1}
    );

__PACKAGE__->table('use_class2activity');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(use_class => 'SmartSea::Schema::Result::UseClass');
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my $self = shift;
    return $self->use_class->name.' -> '.$self->activity->name;
}

1;
