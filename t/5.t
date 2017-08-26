use Modern::Perl;
use File::Basename;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Plack::Builder;
use JSON;

use Data::Dumper;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');
use_ok('SmartSea::Plans');

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};

my $client = {
    schema => SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options),
    user => 'guest',
};

$client->{parameters} = {
    name => '',
    allocation => 1,
    computation_method => 11,
    descr => 3,
    layer_class => 4,
    owner => 5,
    use => 10,
    
    rule_system_is => 1,
    rule_class => 2,
    
    style_is => 1,
    max => 6,
    palette => 7,
    min => 8,
    classes => 9,

    ecosystem_component => 1,
    pressure => 1,
    pressure_class => 1,
    range => 1,
    activity => 1,
    category => 1,
    d => 1,
    rule_system => 1,
    use_class => 1,
    plan => 1,
};
for my $source (sort $client->{schema}->sources) {
    my $obj = SmartSea::Object->new({source => $source, app => $client});
    my $columns = $obj->columns;
    my @err = $obj->values_from_parameters($columns);
    #print STDERR Dumper $columns if $source eq 'ImpactLayer';
    if ($source eq 'ImpactLayer') {
        ok($columns->{super}{columns}{style}{columns}{palette}{value} == 7, "value in part of super");
    }
}
$client->{parameters} = {};

$client->{schema}->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$client->{schema}->resultset('UseClass')->new({id => 1, name => 'use_class'})->insert;
$client->{schema}->resultset('Use')->new({id => 2, plan => 1, use_class => 1})->insert;

my $use = SmartSea::Object->new({source => 'Use', id => 2, app => $client});
my $layer = SmartSea::Object->new({source => 'ImpactLayer', app => $client});

my $columns = $layer->columns;

$client->{parameters} = {layer_class => 5};

done_testing();
