package SmartSea::Schema::Result::Op;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core Exporter/;
use SmartSea::HTML qw(:all);

use constant OPS => ('>=', '<=', '>', '<', '==', 'NOT');

require Exporter;
our @EXPORT_OK = qw(OPS);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('ops');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
