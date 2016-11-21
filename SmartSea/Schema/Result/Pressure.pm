package SmartSea::Schema::Result::Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.pressures');
__PACKAGE__->add_columns(qw/ id order title category /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'pressure');
__PACKAGE__->many_to_many(activities => 'activity2pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

1;
