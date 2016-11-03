package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.plans');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');

1;
