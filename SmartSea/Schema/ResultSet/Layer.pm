package SmartSea::Schema::ResultSet::Layer;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {use => $parent->id, layer_class => $parameters->{layer_class}};
}

1;
