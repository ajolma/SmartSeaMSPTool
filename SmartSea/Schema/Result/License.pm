package SmartSea::Schema::Result::License;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, required => 1},
    url  => {data_type => 'text', html_size => 30}
    );

__PACKAGE__->table('licenses');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
