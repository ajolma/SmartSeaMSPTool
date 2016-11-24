package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.layers');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'layer');
__PACKAGE__->many_to_many(uses => 'use2layer', 'use');

1;
