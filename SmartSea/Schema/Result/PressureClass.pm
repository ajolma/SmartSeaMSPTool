package SmartSea::Schema::Result::PressureClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id       => {},
    name     => { data_type => 'text',  html_size => 30, not_null => 1 },
    ordr     => { data_type => 'text',  html_size => 10 },
    category => { is_foreign_key => 1, source => 'PressureCategory', not_null => 1 },
    );

__PACKAGE__->table('pressure_classes');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(pressure => 'SmartSea::Schema::Result::Pressure', 'pressure_class');
__PACKAGE__->many_to_many(activities => 'pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

1;
