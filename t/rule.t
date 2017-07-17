use Modern::Perl;
use File::Basename;
use Test::More;
use Plack::Test;
use HTTP::Cookies;
use HTTP::Request::Common;
use Plack::Builder;
use JSON;

use Data::Dumper;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');
use_ok('SmartSea::Plans');
use_ok('SmartSea::Browser');

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

my $parser = XML::LibXML->new(no_blanks => 1);
my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");

my $app = builder {
    mount "/plans" => SmartSea::Plans->new(
    {
        schema => $schema,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0,
        js => 0,
        root => '/plans'
    })->to_app;
    mount "/browser" => SmartSea::Browser->new(
    {
        schema => $schema,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0,
        js => 0,
        root => '/browser'
    })->to_app;
};

$schema->resultset('RuleClass')->new({id => 1, name => 'test'})->insert;
$schema->resultset('RuleSystem')->new({id => 1, rule_class => 1})->insert;
$schema->resultset('Rule')->new({id => 1, rule_system => 1, value => 1.5})->insert;

my $host = 'http://127.0.0.1';

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(POST "$host/browser/rule:1?request=modify", [ value => 2.5 ] );
    ok($res->content eq 'Forbidden', "Forbidden to update without cookie.");
    
    $res = $cb->(GET "$host/plans");

    my $jar = HTTP::Cookies->new;
    $jar->extract_cookies($res);

    my @cookies;
    $jar->scan( sub { @cookies = @_ });

    ok($cookies[1] eq 'SmartSea', "Calling /plans sets a cookie.");

    my $req = POST "$host/browser/rule:1?request=modify", [ value => 2.5 ];
    $jar->add_cookie_header($req);
    #print STDERR Dumper $req;
    
    $res = $cb->($req);
    $res = decode_json $res->content;
    #print STDERR Dumper $res;
    
    ok($res->{object}{value} == 2.5, "Update ok with cookie.");

    $req = POST "$host/browser/rule:1?request=modify", [ value => 3.5 ];
    $jar->add_cookie_header($req);

    $res = $cb->($req);

    my @all = select_all($schema, 'id,cookie,value', 'rules');
    ok(@all == 2, "After two updates there is only two rows in rules.");
    ok($all[1][2] == 3.5, "After two updates the cookied value is the latest.");
    
    #print STDERR Dumper \@all;
    #say STDERR $res->content;
};

done_testing();
