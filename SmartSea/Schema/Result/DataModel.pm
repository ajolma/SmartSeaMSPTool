package SmartSea::Schema::Result::DataModel;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('data.data_models');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

1;
