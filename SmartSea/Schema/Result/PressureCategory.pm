package SmartSea::Schema::Result::PressureCategory;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('pressure_categories');
__PACKAGE__->add_columns(qw/id name/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(pressure_classes => 'SmartSea::Schema::Result::PressureClass', 'category');

sub attributes {
    return {name => {i => 0, input => 'text'}};
}

1;
