package SmartSea::Schema::Result::License;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('data.licenses');
__PACKAGE__->add_columns(qw/ id name url /);
__PACKAGE__->set_primary_key('id');

1;
