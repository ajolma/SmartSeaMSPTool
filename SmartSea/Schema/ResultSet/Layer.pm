package SmartSea::Schema::ResultSet::Layer;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent) = @_;
    return {plan2use => $parent->id};
}

1;
