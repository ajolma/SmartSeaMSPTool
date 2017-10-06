use strict;
use warnings;
use 5.010000;

use lib '.';
use SmartSea::Schema;
use SmartSea::Schema::Result::DataModel qw/:all/;
use SmartSea::Schema::Result::NumberType qw/:all/;
use SmartSea::Schema::Result::RuleClass qw/:all/;
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

my @palettes = (PALETTES);
my $id = 0;
my %palettes = map {$id++ => $_} @palettes;

sql({
    schema => 'tool',
    source => 'Palette',
    data => \%palettes
});
exit;

sql({
    schema => 'data',
    source => 'DataModel',
    data => {
        VECTOR_DATA+0 => 'Vector',
        RASTER_DATA+0 => 'Raster'},
    
});

sql({
    schema => 'tool',
    source => 'NumberType',
    data => {
        INTEGER_NUMBER+0 => 'Integer',
        REAL_NUMBER+0 => 'Real',
        BOOLEAN+0 => 'Boolean'
    }
});

sql({
    schema => 'tool',
    source => 'RuleClass',
    data => {
        EXCLUSIVE_RULE+0 => 'Exclusive',
        #MULTIPLICATIVE_RULE+0 => 2,
        #ADDITIVE_RULE+0 => 2,
        INCLUSIVE_RULE+0 => 'Inclusive',
        BOXCAR_RULE+0 => 'Boxcar',
        BAYESIAN_NETWORK_RULE+0 => 'Bayesian network',
    }
});

sub sql {
    my $options = shift;
    for my $id (sort {$a <=> $b} keys %{$options->{data}}) {
        say "insert into ",
        $options->{schema},'.',$schema->source($options->{source})->from(),
        "(id, name) ",
        "values ",
        "($id,'$options->{data}{$id}');";
    }
}
