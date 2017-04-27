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
    super              => { input => '' },
    allocation         => { i => 1, input => 'lookup', source => 'Layer' },
    computation_method => { i => 2, input => 'lookup', source => 'ImpactComputationMethod' }
    );

__PACKAGE__->table('impact_layers');
__PACKAGE__->add_columns(keys %attributes);
__PACKAGE__->set_primary_key(qw/ super /);
__PACKAGE__->belongs_to(super => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(allocation => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(computation_method => 'SmartSea::Schema::Result::ImpactComputationMethod');

__PACKAGE__->has_many(il2ec => 'SmartSea::Schema::Result::ImpactLayer2EcosystemComponent', 'impact_layer');
__PACKAGE__->many_to_many(ecosystem_components => 'il2ec', 'ecosystem_component');

sub superclass {
    return 'Layer';
}

sub id {
    my $self = shift;
    return $self->super->id;
}

sub children_listers {
    return {
        ecosystem_components => {
            col => 'ecosystem_component',
            source => 'EcosystemComponent',
            link_source => 'ImpactLayer2EcosystemComponent',
            ref_to_me => 'impact_layer',
            ref_to_child => 'ecosystem_component',
            class_name => 'Ecosystem components',
            editable_children => 0,
            for_child_form => sub {
                my ($self, $children) = @_;
                my $has = $self->{object}->ecosystem_components($self);
                for my $obj (@$children) {
                    $has->{$obj->id} = 1;
                }
                my @objs;
                for my $obj ($self->{schema}->resultset('EcosystemComponent')->all) {
                    next if $has->{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'ecosystem_component', objs => \@objs);
            }
        }
    };
}

sub need_form_for_child {
    my ($class, $child_source) = @_;
    return 1 if $child_source eq 'Rule'; # Rule is embedded
    return 0; # link to EcosystemComponent can be created directly
}

sub attributes {
    return dclone(\%attributes);
}

sub name {
    my $self = shift;
    my $use = $self->super->use;
    return $use->plan->name.'.'.$use->use_class->name.'.'.$self->super->layer_class->name;
}

1;
