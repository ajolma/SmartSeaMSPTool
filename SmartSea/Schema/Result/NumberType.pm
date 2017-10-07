package SmartSea::Schema::Result::NumberType;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core Exporter/;

# type ids are hard coded here
# we just assume the database is the same as this
# if creating new db, use these
use constant INTEGER_NUMBER => 1;
use constant REAL_NUMBER => 2;
use constant BOOLEAN => 3;
use constant NUMBER_TYPES => qw/Integer Real Boolean/;
require Exporter;
our @EXPORT_OK = qw(NUMBER_TYPES INTEGER_NUMBER REAL_NUMBER BOOLEAN);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use SmartSea::HTML qw(:all);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('number_types');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
