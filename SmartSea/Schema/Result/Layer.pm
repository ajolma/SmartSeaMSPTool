package SmartSea::Schema::Result::Layer;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.layers');
__PACKAGE__->add_columns(qw/ id data /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'layer');
__PACKAGE__->many_to_many(uses => 'use2layer', 'use');

1;
