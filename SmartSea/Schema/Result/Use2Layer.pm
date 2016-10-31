package SmartSea::Schema::Result::Use2Layer;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.use2layer');
__PACKAGE__->add_columns(qw/ use layer /);
__PACKAGE__->set_primary_key(qw/ use layer /);
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(layer => 'SmartSea::Schema::Result::Layer');

1;
