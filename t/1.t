use Modern::Perl;
use File::Basename;
use Test::More;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

my $schema = one_schema();

$schema->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$schema->resultset('UseClass')->new({id => 1, name => 'use_class'})->insert;
$schema->resultset('LayerClass')->new({id => 1, name => 'layer_class'})->insert;
$schema->resultset('RuleClass')->new({id => 1, name => 'rule_class'})->insert;
$schema->resultset('ColorScale')->new({id => 1, name => 'color_scale'})->insert;
$schema->resultset('Style')->new({id => 1, color_scale => 1})->insert;

$schema->resultset('Plan')->single({id => 1})->
    create_related('uses', {id => 1, plan => 1, 'use_class' => 1});

$schema->resultset('LayerClass')->single({id => 1})->
    create_related('layers', {id => 1, use => 1, rule_class => 1, style => 1});

my $root = 'SmartSea::Schema::Result::';
my $parameters = {request => '', add => ''};

for my $class ($schema->sources) {
    #next if $class =~ /2/;
    $class =~ s/([a-z])([A-Z])/$1_$2/;
    $class = lc($class);
    my $obj = SmartSea::Object->new({schema => $schema, url => '', lc_class => $class});
    my $result = $obj->li;
    ok(ref $result eq 'ARRAY', "$class simple HTML list");
}

for my $schema (keys %$schemas) {
    unlink "$schema.db";
}

done_testing();
