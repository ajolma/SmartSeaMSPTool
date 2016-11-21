package SmartSea::Schema::Result::Plan2Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.plan2use');
__PACKAGE__->add_columns(qw/ plan use /);
__PACKAGE__->set_primary_key(qw/ plan use /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');

1;
