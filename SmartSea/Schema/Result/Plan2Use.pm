package SmartSea::Schema::Result::Plan2Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('plan2use');
__PACKAGE__->add_columns(qw/ id plan use /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');

__PACKAGE__->has_many(layer_class => 'SmartSea::Schema::Result::Layer', 'plan2use');
__PACKAGE__->many_to_many(layer_classes => 'layer_class', 'layer_class');

1;
