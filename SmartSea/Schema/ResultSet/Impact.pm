package SmartSea::Schema::ResultSet::Impact;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return unless $parent;
    return {pressure => $parent->id, ecosystem_component => $parameters->{ecosystem_component}};
}

1;
