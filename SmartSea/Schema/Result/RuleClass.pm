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
use constant BAYESIAN_NETWORK_RULE => 6;
use constant RULE_CLASSES => ('Exclusive', 'Multiplicative', 'Additive', 'Inclusive', 'Boxcar', 'Bayesian network');
require Exporter;
our @EXPORT_OK = qw(RULE_CLASSES EXCLUSIVE_RULE INCLUSIVE_RULE
                    MULTIPLICATIVE_RULE ADDITIVE_RULE 
                    BOXCAR_RULE 
                    BAYESIAN_NETWORK_RULE);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('rule_classes');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);

1;
