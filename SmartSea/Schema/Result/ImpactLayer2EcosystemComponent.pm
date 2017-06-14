package SmartSea::Schema::Result::ImpactLayer2EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

my @columns = (
    id                  => {},
    impact_layer        => {is_foreign_key => 1, source => 'ImpactLayer', target => 'super', not_null => 1},
    ecosystem_component => {is_foreign_key => 1, source => 'EcosystemComponent', not_null => 1}
    );

__PACKAGE__->table('impact_layer2ecosystem_component');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(impact_layer => 'SmartSea::Schema::Result::ImpactLayer');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');

sub order_by {
    return {};
}

sub name {
    my $self = shift;
    return $self->impact_layer->name.' -> '.$self->ecosystem_component->name;
}

1;
