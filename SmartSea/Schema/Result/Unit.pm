package SmartSea::Schema::Result::Unit;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('data.units');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

1;
