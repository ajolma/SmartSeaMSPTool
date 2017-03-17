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

my $data_schema  = SmartSea::Schema->connect('dbi:SQLite:data.db');
my $tool_schema  = SmartSea::Schema->connect('dbi:SQLite:tool.db');

my $plan_rs = $tool_schema->resultset('Plan');
can_ok($plan_rs->result_class, qw/id name uses/);

for my $schema (keys %$schemas) {
    unlink "$schema.db";
}

done_testing();
