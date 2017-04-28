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

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

for my $source (sort $schema->sources) {
    my $rs = $schema->resultset($source);
    can_ok($rs->result_class, qw/id name/);
    $rs = 'SmartSea::Schema::Result::'.$source;
    my @cols = $rs->columns;
    my $info = $rs->columns_info;
}

unlink "tool.db";
unlink "data.db";

done_testing();
