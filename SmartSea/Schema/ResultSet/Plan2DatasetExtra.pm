package SmartSea::Schema::ResultSet::Plan2DatasetExtra;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return unless $parent;
    return {plan => $parent->id, dataset => $parameters->{extra_dataset}};
}

1;
