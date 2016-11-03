package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.uses');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'use');
__PACKAGE__->many_to_many(layers => 'use2layer', 'layer');
__PACKAGE__->has_many(use2impact => 'SmartSea::Schema::Result::Use2Impact', 'use');
__PACKAGE__->many_to_many(impacts => 'use2impact', 'impact');

1;
