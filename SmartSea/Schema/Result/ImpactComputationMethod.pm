package SmartSea::Schema::Result::ImpactComputationMethod;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('impact_computation_methods');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

sub attributes {
    return {
        name => {i => 1, input => 'text'}
    };
}

1;
