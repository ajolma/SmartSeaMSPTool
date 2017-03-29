package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my %attributes = (
    use         => { i => 1, input => 'ignore', class => 'Use' },
    layer_class => { i => 2, input => 'ignore', class => 'LayerClass' },
    rule_class  => { i => 3, input => 'lookup', class => 'RuleClass' },
    style       => { i => 4, input => 'object', class => 'Style', required => 1 },
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
    return \%attributes;
}

sub children_listers {
    return { rules => [rule => 0] };
}

sub order_by {
    return {-asc => 'id'};
}

sub class_name {
    my ($self, $parent, $purpose) = @_;
    return 'Layer' if blessed($self) && $purpose && $purpose eq 'list';
    return $self->layer_class->name.' Layer' if blessed($self);
    return 'Layer';
}

sub name {
    my $self = shift;
    return $self->layer_class->name;
}

sub long_name {
    my $self = shift;
    return $self->use->name.' <-> '.$self->layer_class->name;
}

sub my_unit {
    return '';
}

1;
