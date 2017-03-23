package SmartSea::Schema::ResultSet::Rule;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent) = @_;
    return {layer => $parent->id};
}

1;
