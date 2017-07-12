package SmartSea::Schema::Result::RuleClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core Exporter/;

# method ids are hard coded here
# we just assume the database is the same as this
# if creating new db, use these
use constant EXCLUSIVE_RULE => 1;
use constant MULTIPLICATIVE_RULE => 2;
use constant ADDITIVE_RULE => 3;
use constant INCLUSIVE_RULE => 4;
use constant BOXCAR_RULE => 5;
require Exporter;
our @EXPORT_OK = qw(EXCLUSIVE_RULE MULTIPLICATIVE_RULE ADDITIVE_RULE INCLUSIVE_RULE BOXCAR_RULE);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('rule_classes');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);

1;
