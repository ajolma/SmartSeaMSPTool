package SmartSea::Schema::Result::ImpactLayer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my %attributes = (
    allocation         => { i => 1, input => 'lookup', source => 'Layer' },
    computation_method => { i => 2, input => 'lookup', source => 'ImpactComputationMethod' }
    );

__PACKAGE__->table('impact_layers');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(id => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(allocation => 'SmartSea::Schema::Result::Layer');

__PACKAGE__->has_many(il2ec => 'SmartSea::Schema::Result::ImpactLayer2EcosystemComponent', 'impact_layer');
__PACKAGE__->many_to_many(ecosystem_components => 'il2ec', 'ecosystem_component');

sub attributes {
    return dclone(\%attributes);
}

sub name {
    my $self = shift;
    my $use = $self->id->use;
    return $use->plan->name.'.'.$use->use_class->name.'.'.$self->id->layer_class->name;
}

1;
