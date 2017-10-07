use strict;
use warnings;
use 5.010000;

use lib '.';
use SmartSea::Schema;
use SmartSea::Schema::Result::Op qw/:all/;
use SmartSea::Schema::Result::DataModel qw/:all/;
use SmartSea::Schema::Result::NumberType qw/:all/;
use SmartSea::Schema::Result::RuleClass qw/:all/;
use SmartSea::Schema::Result::BoxcarRuleType qw/:all/;
use SmartSea::Schema::Result::Palette qw/:all/;

my $db_name = 'SmartSea-demo';
my $db_user = 'smartsea';
my $db_passwd = 'smartsea';
my $on_connect = "SET search_path TO tool,data,public";

my $schema = SmartSea::Schema->connect(
    "dbi:Pg:dbname=$db_name",
    $db_user,
    $db_passwd,
    { on_connect_do => [$on_connect] });

sql({
    schema => 'tool',
    source => 'Palette',
    data => [PALETTES]
});

sql({
    schema => 'data',
    source => 'DataModel',
    data => [DATA_MODEL]
});

sql({
    schema => 'tool',
    source => 'NumberType',
    data => [NUMBER_TYPES]
});

sql({
    schema => 'tool',
    source => 'RuleClass',
    data => [RULE_CLASSES]
});

sql({
    schema => 'tool',
    source => 'BoxcarRuleType',
    data => [BOXCAR_RULE_TYPES]
});

sql({
    schema => 'tool',
    source => 'Op',
    data => [OPS]
});

sub sql {
    my $options = shift;
    my $id = 1;
    for my $name (@{$options->{data}}) {
        say "insert into ",
        $options->{schema},'.',$schema->source($options->{source})->from(),
        "(id, name) ",
        "values ",
        "($id,'$name');";
        $id++;
    }
}
