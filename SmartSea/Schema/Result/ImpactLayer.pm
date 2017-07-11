package SmartSea::Schema::Result::ImpactLayer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my @columns = (
    super => {
        is_foreign_key => 1,
        is_superclass => 1,
        not_null => 1,
        source => 'Layer',
    },
    allocation => { 
        is_foreign_key => 1,
        source => 'Layer',
        not_null => 1,
        objs => sub {my $obj = shift; return $obj->layer_class->name eq 'Allocation' },
    },
    computation_method => { 
        is_foreign_key => 1,
        not_null => 1,
        source => 'ImpactComputationMethod'
    }
    );

__PACKAGE__->table('impact_layers');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ super /);
__PACKAGE__->belongs_to(super => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(allocation => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(computation_method => 'SmartSea::Schema::Result::ImpactComputationMethod');

sub id {
    my $self = shift;
    return $self->super->id;
}

sub need_form_for_child {
    my ($class, $child_source) = @_;
    return 1 if $child_source eq 'Rule'; # Rule is embedded
    return 0; # link to EcosystemComponent can be created directly
}

sub name {
    my $self = shift;
    my $use = $self->super->use;
    return $use->plan->name.'.'.$use->use_class->name.'.'.$self->super->layer_class->name;
}

1;
