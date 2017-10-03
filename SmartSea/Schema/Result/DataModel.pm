package SmartSea::Schema::Result::DataModel;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core Exporter/;
use SmartSea::HTML qw(:all);

# type ids are hard coded here
# we just assume the database is the same as this
# if creating new db, use these
use constant VECTOR_DATA => 1;
use constant RASTER_DATA => 2;
require Exporter;
our @EXPORT_OK = qw(VECTOR_DATA RASTER_DATA);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('data_models');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
