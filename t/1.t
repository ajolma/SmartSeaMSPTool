use Modern::Perl;
use File::Basename;
use Test::More;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

my $schema = one_schema();

$schema->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$schema->resultset('Use')->new({id => 1, name => 'use'})->insert;
$schema->resultset('LayerClass')->new({id => 1, name => 'layer_class'})->insert;
$schema->resultset('RuleClass')->new({id => 1, name => 'rule_class'})->insert;
$schema->resultset('ColorScale')->new({id => 1, name => 'color_scale'})->insert;
$schema->resultset('Style')->new({id => 1, color_scale => 1})->insert;

$schema->resultset('Plan')->single({id => 1})->
    create_related('plan2use', {id => 1, plan => 1, 'use' => 1});

$schema->resultset('LayerClass')->single({id => 1})->
    create_related( 'layers', {id => 1, plan2use => 1, rule_class => 1, style2 => 1});

my $root = 'SmartSea::Schema::Result::';
my $parameters = {request => '', add => ''};

for my $class (qw/Plan Use LayerClass RuleClass ColorScale Style Layer/) {
    my $klass = $root.$class;
    my $object = $klass->get_object(oids => [1], schema => $schema);
    my $result = $klass->HTML_list([$schema->resultset($class)->all]);
    ok(ref $result eq 'ARRAY', "$class simple HTML list");
    $result = $object->HTML_div({}, parameters => $parameters, schema => $schema);
    ok(ref $result eq 'ARRAY', "$class simple HTML div");
    $result = $object->HTML_form({}, {}, oids => [], schema => $schema);
    ok(ref $result eq 'ARRAY', "$class simple HTML form");
}

{
    my $class = 'Use';
    my $klass = $root.$class;
    my $object = $klass->get_object(oids => [1], schema => $schema);
    my $result = $object->HTML_div({}, parameters => $parameters, plan => 1, schema => $schema);
    ok(ref $result eq 'ARRAY', "$class HTML div with parent");
}

{
    my $class = 'Use';
    my $klass = $root.$class;
    my $object = $klass->get_object(oids => [1], schema => $schema);
    my $result = $object->HTML_div({}, parameters => $parameters, plan => 1, oids => ['layer:1'], schema => $schema);
    ok(ref $result eq 'ARRAY', "$class HTML div with parent and child");
}

for my $schema (keys %$schemas) {
    unlink "$schema.db";
}

done_testing();
