package SmartSea::Schema::Result::Organization;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('data.organizations');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

1;
