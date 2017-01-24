package SmartSea::Schema::Result::Plan2Use2Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.plan2use2layer');
__PACKAGE__->add_columns(qw/ id plan2use layer rule_class /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan2use => 'SmartSea::Schema::Result::Plan2Use');
__PACKAGE__->belongs_to(layer => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(rule_class => 'SmartSea::Schema::Result::RuleClass');

__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', 'plan2use2layer');

1;