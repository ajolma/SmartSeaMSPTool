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
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");

my $service = SmartSea::Plans->new(
    {
        schema => $schema,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0,
        no_js => 1
    });
my $app = $service->to_app;

$schema->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$schema->resultset('UseClass')->new({id => 1, name => 'use_class'})->insert;
$schema->resultset('Use')->new({id => 1, plan => 1, use_class => 1})->insert;
$schema->resultset('LayerClass')->new({id => 1, name => 'layer_class'})->insert;
$schema->resultset('ColorScale')->new({id => 1, name => 'color scale'})->insert;
$schema->resultset('Style')->new({id => 1, color_scale => 1})->insert;
$schema->resultset('RuleClass')->new({id => 1, name => 'rule class'})->insert;
$schema->resultset('RuleSystem')->new({id => 1, rule_class => 1})->insert;
$schema->resultset('Layer')->new({id => 1, use => 1, layer_class => 1, style => 1, rule_system => 1})->insert;
$schema->resultset('Dataset')->new({id => 1, name => 'dataset', path => "not real", style => 1})->insert;

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/");
    my $content = $res->content;
    my $plans;
    eval {
        $plans = decode_json $content;
    };
    
    # is the response ok and JSON?
    say STDERR $content,"\n",$@ if $@;
    ok(!$@, "/plans is JSON");
    return if $@;

    # is the plans what it should be?
    my $ok = @$plans == 3;
    $ok = $plans->[0]{name} eq 'plan' if $ok;
    $ok = $plans->[1]{name} eq 'Data' && $plans->[1]{id} == 0 if $ok;
    $ok = $plans->[2]{name} eq 'Ecosystem' && $plans->[2]{id} == 1 if $ok;
    print STDERR Dumper $plans unless $ok;
    ok($ok, "/plans has ok structure");
};

done_testing();

