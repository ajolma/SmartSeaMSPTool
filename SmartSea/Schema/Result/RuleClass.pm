package SmartSea::Schema::Result::RuleClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('rule_classes');
__PACKAGE__->add_columns(qw/id name/);
__PACKAGE__->set_primary_key(qw/ id /);

1;
