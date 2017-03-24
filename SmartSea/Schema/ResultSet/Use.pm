package SmartSea::Schema::ResultSet::Use;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {plan => $parent->id, 'use' => $parameters->{use}};
}

1;
