package SmartSea::Schema::Result::DataModel;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('data.data_models');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

1;
