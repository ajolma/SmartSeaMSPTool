package SmartSea::Schema::ResultSet::Pressure;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {activity => $parent->id, pressure_class => $parameters->{pressure_class}};
}

1;
