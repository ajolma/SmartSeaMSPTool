package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my @columns = (
    id          => {},
    use         => { is_foreign_key => 1, source => 'Use', parent => 1 },
    layer_class => { is_foreign_key => 1, source => 'LayerClass' },
    rule_system => { is_foreign_key => 1, source => 'RuleSystem', is_composition => 1, required => 1 },
    style       => { is_foreign_key => 1, source => 'Style', is_composition => 1, required => 1 },
    descr       => { data_type => 'text', html_size => 30 }
    );

__PACKAGE__->table('layers');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(layer_class => 'SmartSea::Schema::Result::LayerClass');
__PACKAGE__->belongs_to(rule_system => 'SmartSea::Schema::Result::RuleSystem');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');
__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', {'foreign.rule_system' => 'self.rule_system'});

# subclassing made with a new table with id pointing to superclass table's if
# use this method to tell whether an entry is required into this table too
sub subclass {
    my ($self, $parameters) = @_;
    return 'ImpactLayer' if $self->layer_class->name eq 'Impact';
}

sub children_listers {
    return { 
        rules => {
            source => 'Rule',
            class_name => 'Rules',
            child_is_mine => 1,
            for_child_form => sub {
                my ($self, $children) = @_;
                return undef;
            }
        }
    };
}

sub column_values_from_context {
    my ($self, $parent, $parameters) = @_;
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
