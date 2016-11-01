package SmartSea::Schema::Result::Plan;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.plans');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');

1;
