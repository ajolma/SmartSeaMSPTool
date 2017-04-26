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
use_ok('SmartSea::Service');

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

my $parser = XML::LibXML->new(no_blanks => 1);
my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");

my $service = SmartSea::Service->new(
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
$schema->resultset('LayerClass')->new({id => 1, name => 'Allocation'})->insert;
$schema->resultset('LayerClass')->new({id => 2, name => 'Impact'})->insert;
$schema->resultset('ColorScale')->new({id => 1, name => 'color scale'})->insert;
$schema->resultset('Style')->new({id => 1, color_scale => 1})->insert;
$schema->resultset('RuleClass')->new({id => 1, name => 'rule class'})->insert;
$schema->resultset('RuleSystem')->new({id => 1, rule_class => 1})->insert;
$schema->resultset('EcosystemComponent')->new({id => 1, name => 'component_1'})->insert;
$schema->resultset('ImpactComputationMethod')->new({id => 1, name => 'method_1'})->insert;

$schema->resultset('Dataset')->new({id => 1, name => 'dataset', path => "not real", style => 1})->insert;

$schema->resultset('Layer')->new({id => 1, use => 1, layer_class => 1, style => 1, rule_system => 1})->insert;


test_psgi $app, sub {
    my $cb = shift;
    my $post = [
        use => 1, 
        layer_class => 2, 
        style_is => 1, 
        color_scale => 1,
        rule_class => 1,
        allocation => 1,
        computation_method => 1
    ];
    my $res = $cb->(POST "/browser/plan:1/use:1/layer?save", $post);
    eval {
        $parser->load_xml(string => $res->content);
    };
    ok(!$@, "Impact layer creation 1/2");
    my $i = 0;
    my @layer;
    for my $layer ($schema->resultset('ImpactLayer')->all) {
        @layer = ($layer->super->id, $layer->allocation->id);
        ++$i;
    }
    ok($layer[0] == 2 && $layer[1] == 1, "Impact layer creation 2/2");
    $post = [
        ecosystem_component => 1,
        submit => 'Add'
    ];
    $res = $cb->(POST "/browser/plan:1/use:1/layer:2/ecosystem_component", $post);
    $i = 0;
    @layer = ();
    for my $link ($schema->resultset('ImpactLayer2EcosystemComponent')->all) {
        @layer = ($link->impact_layer->id, $link->ecosystem_component->id);
        ++$i;
    }
    ok($layer[0] == 2 && $layer[1] == 1, "Link to ecosystem component created");
};

my $layer = SmartSea::Object->new({source => 'Layer', id => 2}, {schema => $schema});
ok($layer->{source} eq 'ImpactLayer' && ref($layer->{object}) eq 'SmartSea::Schema::Result::ImpactLayer', 
   "Polymorphic new gives: $layer->{object}");

my $descr = 'this is description';
$layer->update(undef, -1, {descr => $descr});
ok($schema->resultset('Layer')->single({id => 2})->descr eq $descr, "Set superclass attribute.");

$layer->delete(undef, -1);
my $i = 0;
my $layer_id;
for my $layer ($schema->resultset('Layer')->all) {
    $layer_id = $layer->id;
    ++$i;
}
ok($i == 1 && $layer_id == 1, "Delete ImpactLayer.");

done_testing();
