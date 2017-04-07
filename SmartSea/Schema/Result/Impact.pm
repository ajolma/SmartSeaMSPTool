package SmartSea::Schema::Result::Impact;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my %attributes = (
    pressure            => { i => 1, input => 'ignore', source => 'Pressure' },
    ecosystem_component => { i => 2, input => 'lookup', source => 'EcosystemComponent' },
    strength            => { i => 3, input => 'text', size => 10 },
    belief              => { i => 4, input => 'text', size => 10 },
    );

__PACKAGE__->table('impacts');
__PACKAGE__->add_columns(qw/ id pressure ecosystem_component strength belief /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(pressure => 'SmartSea::Schema::Result::Pressure');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');

sub attributes {
    return \%attributes;
}

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my ($self) = @_;
    return $self->pressure->name.' <-> '.$self->ecosystem_component->name;
}

1;
