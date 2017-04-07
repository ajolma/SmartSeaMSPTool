package SmartSea::Schema::Result::PressureClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

my %attributes = (
    name     => { i => 1,  input => 'text',  size => 20 },
    ordr     => { i => 2,  input => 'text',  size => 10 },
    category => { i => 3,  input => 'lookup', source => 'PressureCategory' },
    );

__PACKAGE__->table('pressure_classes');
__PACKAGE__->add_columns(qw/ id ordr name category /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(pressure => 'SmartSea::Schema::Result::Pressure', 'pressure_class');
__PACKAGE__->many_to_many(activities => 'pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

sub attributes {
    return \%attributes;
}

1;
