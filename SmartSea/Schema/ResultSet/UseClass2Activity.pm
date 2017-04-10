package SmartSea::Schema::ResultSet::UseClass2Activity;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return unless $parent;
    return {use_class => $parent->id, activity => $parameters->{activity}};
}

1;
