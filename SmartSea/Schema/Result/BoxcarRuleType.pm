package SmartSea::Schema::Result::BoxcarRuleType;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core Exporter/;
use SmartSea::HTML qw(:all);

use constant BOXCAR_RULE_TYPES => ('Normal _/¯\_', 'Inverted ¯\_/¯');

require Exporter;
our @EXPORT_OK = qw(BOXCAR_RULE_TYPES);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('boxcar_rule_types');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

1;
