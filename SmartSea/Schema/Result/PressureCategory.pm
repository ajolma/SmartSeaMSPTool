package SmartSea::Schema::Result::PressureCategory;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.pressure_categories');
__PACKAGE__->add_columns(qw/id name/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(pressures => 'SmartSea::Schema::Result::Pressure', 'category');

1;
