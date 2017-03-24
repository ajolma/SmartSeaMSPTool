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

my $tool_schema  = SmartSea::Schema->connect('dbi:SQLite:tool.db');
my $data_schema  = SmartSea::Schema->connect('dbi:SQLite:data.db');

for my $source ($tool_schema->sources) {
    my $rs = $tool_schema->resultset($source);
    can_ok($rs->result_class, qw/id name/);
}

for my $source ($data_schema->sources) {
    my $rs = $data_schema->resultset($source);
    can_ok($rs->result_class, qw/id name/);
}

for my $schema (keys %$schemas) {
    unlink "$schema.db";
}

done_testing();
