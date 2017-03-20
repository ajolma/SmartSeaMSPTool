package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('layers');
__PACKAGE__->add_columns(qw/ id plan2use layer_class rule_class style2 descr /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan2use => 'SmartSea::Schema::Result::Plan2Use');
__PACKAGE__->belongs_to(layer_class => 'SmartSea::Schema::Result::LayerClass');
__PACKAGE__->belongs_to(rule_class => 'SmartSea::Schema::Result::RuleClass');
__PACKAGE__->belongs_to(style2 => 'SmartSea::Schema::Result::Style');

__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', 'layer');

sub my_unit {
    return '';
}

1;
