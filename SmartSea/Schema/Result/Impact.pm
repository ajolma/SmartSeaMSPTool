package SmartSea::Schema::Result::Impact;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id                  => {},
    pressure            => { is_foreign_key => 1, source => 'Pressure', parent => 1 },
    ecosystem_component => { is_foreign_key => 1, source => 'EcosystemComponent' },
    strength            => { is_foreign_key => 1, source => 'ImpactStrength' },
    belief              => { is_foreign_key => 1, source => 'Belief' },
    );

__PACKAGE__->table('impacts');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(pressure => 'SmartSea::Schema::Result::Pressure');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');
__PACKAGE__->belongs_to(strength => 'SmartSea::Schema::Result::ImpactStrength');
__PACKAGE__->belongs_to(belief => 'SmartSea::Schema::Result::Belief');

sub order_by {
    return {-asc => 'id'};
}

sub column_values_from_context {
    my ($self, $parent, $parameters) = @_;
    return {pressure => $parent->id, ecosystem_component => $parameters->{ecosystem_component}};
}

sub name {
    my ($self) = @_;
    return $self->pressure->name.' <-> '.$self->ecosystem_component->name;
}

1;
