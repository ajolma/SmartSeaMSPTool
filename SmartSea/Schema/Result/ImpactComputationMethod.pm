package SmartSea::Schema::Result::ImpactComputationMethod;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('impact_computation_methods');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
