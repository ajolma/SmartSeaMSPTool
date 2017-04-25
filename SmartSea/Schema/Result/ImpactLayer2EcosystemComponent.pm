package SmartSea::Schema::Result::ImpactLayer2EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('impact_layer2ecosystem_component');
__PACKAGE__->add_columns(qw/ impact_layer ecosystem_component /);
__PACKAGE__->belongs_to(impact_layer => 'SmartSea::Schema::Result::ImpactLayer');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');

sub attributes {
    return {
        impact_layer => {i => 1, input => 'lookup', source => 'ImpactLayer'},
        ecosystem_component => {i => 2, input => 'lookup', source => 'EcosystemComponent'}
    };
}

sub order_by {
    return {};
}

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {} unless $parent;
    return {impact_layer => $parent->super->id, ecosystem_component => $parameters->{ecosystem_component}};
}

sub name {
    my $self = shift;
    return $self->impact_layer->name.' -> '.$self->ecosystem_component->name;
}

1;
