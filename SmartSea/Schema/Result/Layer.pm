package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my %attributes = (
    use         => { i => 1, input => 'lookup', source => 'Use' },
    layer_class => { i => 2, input => 'lookup', source => 'LayerClass' },
    rule_class  => { i => 3, input => 'lookup', source => 'RuleClass' },
    style       => { i => 4, input => 'object', source => 'Style', required => 1 },
    descr       => { i => 5, input => 'text' }
    );

__PACKAGE__->table('layers');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(layer_class => 'SmartSea::Schema::Result::LayerClass');
__PACKAGE__->belongs_to(rule_class => 'SmartSea::Schema::Result::RuleClass');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');
__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', 'layer');

sub attributes {
    return dclone(\%attributes);
}

sub children_listers {
    return { 
        rules => {
            source => 'Rule',
            ref_to_me => 'layer',
            class_name => 'Rules',
            for_child_form => sub {
                my ($self, $children) = @_;
                return undef;
            }
        }
    };
}

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {} unless $parent;
    return {use => $parent->id, layer_class => $parameters->{layer_class}};
}

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my ($self) = @_;
    return $self->use->plan->name.'.'.$self->use->use_class->name.'.'.$self->layer_class->name;
}

sub my_unit {
    return '';
}

1;
