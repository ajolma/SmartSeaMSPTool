package SmartSea::Schema::Result::Use2Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.use2activity');
__PACKAGE__->add_columns(qw/ id use activity /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');

1;
