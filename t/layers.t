use Modern::Perl;
use File::Basename;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Plack::Builder;
use JSON;
use XML::SemanticDiff;

use Data::Dumper;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');
use_ok('SmartSea::Browser');

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

my $parser = XML::LibXML->new(no_blanks => 1);
my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");

my $app = builder {
    mount "/browser" => SmartSea::Browser->new(
    {
        schema => $schema,
        fake_admin => 1,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0,
        no_js => 1,
        root => '/browser'
    })->to_app;
};

$schema->resultset('Plan')->new({id => 1, name => 'plan', owner => 'ajolma'})->insert;
$schema->resultset('UseClass')->new({id => 1, name => 'use_class'})->insert;
$schema->resultset('Use')->new({id => 1, plan => 1, use_class => 1, owner => 'ajolma'})->insert;
$schema->resultset('LayerClass')->new({id => 1, name => 'Allocation'})->insert;
$schema->resultset('LayerClass')->new({id => 2, name => 'Impact'})->insert;
$schema->resultset('ColorScale')->new({id => 1, name => 'color scale'})->insert;
$schema->resultset('Style')->new({id => 1, color_scale => 1})->insert;
$schema->resultset('RuleClass')->new({id => 1, name => 'rule class'})->insert;
$schema->resultset('RuleSystem')->new({id => 1, rule_class => 1})->insert;
$schema->resultset('EcosystemComponent')->new({id => 1, name => 'component_1'})->insert;
$schema->resultset('ImpactComputationMethod')->new({id => 1, name => 'method_1'})->insert;

$schema->resultset('Dataset')->new({id => 1, name => 'dataset', path => "not real", style => 1})->insert;

$schema->resultset('Layer')->new({id => 1, use => 1, layer_class => 1, style => 1, rule_system => 1, owner => 'ajolma'})->insert;

$schema->resultset('Layer')->new({id => 2, use => 1, layer_class => 2, style => 1, rule_system => 1, owner => 'ajolma'})->insert;
$schema->resultset('ImpactLayer')->new({super => 2, allocation => 1, computation_method => 1})->insert;

for my $l ($schema->resultset('Layer')->all) {
    #say STDERR $l->id," ",$l->name;
}

test_psgi $app, sub {
    my $cb = shift;
    
    my $res = $cb->(GET "/browser/use:1/layer");
    my $dom;
    eval {
        $dom = $parser->load_xml(string => $res->content);
    };
    #pretty_print_XML($res->content);
    my @href;
    for my $a ($dom->documentElement->findnodes('//a')) {
        my $href = $a->getAttribute('href');
        push @href, $href;
        #say STDERR $href;
    }
    ok(@href == 7 && $href[6] eq '/browser/use:1/layer:2?edit', "layer list");

    $res = $cb->(GET "/browser/use:1/layer:2");
    eval {
        $dom = $parser->load_xml(string => $res->content);
    };
    #pretty_print_XML($res->content);
    @href = ();
    for my $a ($dom->documentElement->findnodes('//a')) {
        my $href = $a->getAttribute('href');
        push @href, $href;
        #say STDERR $href;
    }
    ok(@href == 5 && $href[4] eq '/browser/use:1/layer:2?edit', "layer list with impact layer open");

    $res = $cb->(GET "/browser/use:1/layer:2?edit");
    eval {
        $dom = $parser->load_xml(string => $res->content);
    };
    #pretty_print_XML($res->content);
    @href = ();
    for my $a ($dom->documentElement->findnodes('//input')) {
        my $href = $a->getAttribute('name');
        push @href, $href;
        #say STDERR "input: ",$href;
    }
    ok(@href == 10, "10 input elements in impact layer form");
    @href = ();
    for my $a ($dom->documentElement->findnodes('//select')) {
        my $href = $a->getAttribute('name');
        push @href, $href;
        #say STDERR "select: ",$href;
    }
    ok(@href == 5, "5 select elements in impact layer form");
    
};

done_testing();
