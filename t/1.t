use Modern::Perl;
use File::Basename;
use Test::More;
use Data::Dumper;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

$schema->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$schema->resultset('UseClass')->new({id => 1, name => 'use_class'})->insert;
$schema->resultset('LayerClass')->new({id => 1, name => 'layer_class'})->insert;
$schema->resultset('RuleClass')->new({id => 1, name => 'rule_class'})->insert;
$schema->resultset('RuleSystem')->new({id => 1, rule_class => 1})->insert;
$schema->resultset('Palette')->new({id => 1, name => 'palette'})->insert;
$schema->resultset('Style')->new({id => 1, palette => 1})->insert;

$schema->resultset('Plan')->single({id => 1})->
    create_related('uses', {id => 1, plan => 1, 'use_class' => 1});

$schema->resultset('LayerClass')->single({id => 1})->
    create_related('layers', {id => 1, use => 1, rule_system => 1, style => 1});

my $root = 'SmartSea::Schema::Result::';
my $parameters = {request => '', add => ''};

for my $source ($schema->sources) {
    my $obj = SmartSea::Object->new({
        name => '',
        class => '',
        source => $source,
        app => {user => 'guest', schema => $schema, debug => 0}});
    my $result = $obj->item([], {url => ''});
    #print STDERR Dumper $result;
    ok(ref $result eq 'ARRAY', "$source simple HTML list");
    #exit;
}

unlink "tool.db";
unlink "data.db";

done_testing();
