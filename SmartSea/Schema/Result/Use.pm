package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.uses');
__PACKAGE__->add_columns(qw/ id title current_allocation /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'use');
__PACKAGE__->many_to_many(layers => 'use2layer', 'layer');
__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');
__PACKAGE__->belongs_to(current_allocation => 'SmartSea::Schema::Result::Dataset');

1;
