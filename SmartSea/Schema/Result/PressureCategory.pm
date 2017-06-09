package SmartSea::Schema::Result::PressureCategory;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('pressure_categories');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(pressure_classes => 'SmartSea::Schema::Result::PressureClass', 'category');

1;
