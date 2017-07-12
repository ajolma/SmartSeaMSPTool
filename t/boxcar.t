# test boxcar rules

use Modern::Perl;
use File::Basename;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;
use Plack::Builder;
use JSON;
use PDL;

use Data::Dumper;

use lib '.';
use Test::Helper;

use SmartSea::Schema::Result::RuleClass qw(:all);
use SmartSea::Core qw(:all);

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');
use_ok('SmartSea::Plans');
use_ok('SmartSea::Browser');

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

my $style_rs = $schema->resultset('Style');
my $dataset_rs = $schema->resultset('Dataset');

my $tile = Tile->new;

my $args = {
    debug => 0,
    tile => $tile, # needs methods tile, projwin, extent (if epsg is not 3067)
    epsg => $tile->epsg, 
    GDALVectorDataset => undef, # if dataset is db table
    data_dir => $tile->data_dir, # if dataset is raster file
};

$schema->resultset('RuleClass')->new({id => BOXCAR_RULE, name => 'boxcar'})->insert;
$schema->resultset('RuleSystem')->new({id => 1, rule_class => BOXCAR_RULE})->insert;

my $sequences = {
    layer => 1,
    rule => 1,
    dataset => 1,
    style => 1
};

my $dataset = make_dataset($schema, $sequences, $tile, 'Float64', [[1,2,3],[4,5,6],[7,8,9]]);
my $x = $dataset->Piddle($args);

my $rule_id = 1;
my $rule = {
    id => $rule_id, 
    rule_system => 1,
    weight => 2,
    boxcar => 1,
    boxcar_x0 => 1.5,
    boxcar_x1 => 2.5,
    boxcar_x2 => 4.5,
    boxcar_x3 => 7,
    dataset => 1,
};
$rule = $schema->resultset('Rule')->new($rule)->insert;

my $y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[0,1,2],[2,1.6,0.8],[0,0,0]], "Simple boxcar rule");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 0,
        boxcar_x0 => 1.5,
        boxcar_x1 => 2.5,
        boxcar_x2 => 4.5,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[2,1,0],[0,0.4,1.2],[2,2,2]], "Simple inverted boxcar rule");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 1,
        boxcar_x0 => 3,
        boxcar_x1 => 3,
        boxcar_x2 => 4.5,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[0,0,2],[2,1.6,0.8],[0,0,0]], "Boxcar rule with left side vertical");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 1,
        boxcar_x0 => 1.5,
        boxcar_x1 => 2.5,
        boxcar_x2 => 7,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[0,1,2],[2,2,2],[2,0,0]], "Boxcar rule with right side vertical");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 1,
        boxcar_x0 => 3,
        boxcar_x1 => 3,
        boxcar_x2 => 7,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[0,0,2],[2,2,2],[2,0,0]], "Boxcar rule with both sides vertical");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 0,
        boxcar_x0 => 3,
        boxcar_x1 => 3,
        boxcar_x2 => 4.5,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[2,2,2],[0,0.4,1.2],[2,2,2]], "Inverted boxcar rule with left side vertical");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 0,
        boxcar_x0 => 1.5,
        boxcar_x1 => 2.5,
        boxcar_x2 => 7,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[2,1,0],[0,0,0],[2,2,2]], "Inverted boxcar rule with right side vertical");

$rule = $schema->resultset('Rule')->new(
    {
        id => ++$rule_id,
        rule_system => 1,
        dataset => 1,
        weight => 2,
        boxcar => 0,
        boxcar_x0 => 3,
        boxcar_x1 => 3,
        boxcar_x2 => 7,
        boxcar_x3 => 7,
    })->insert;
$y = zeroes($tile->size);
$rule->apply($y, $args);

#print $y;
is_deeply(unpdl($y), [[2,2,2],[0,0,0],[2,2,2]], "Inverted boxcar rule with both sides vertical");



done_testing();
