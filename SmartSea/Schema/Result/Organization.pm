package SmartSea::Schema::Result::Organization;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, required => 1}
    );

__PACKAGE__->table('organizations');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
