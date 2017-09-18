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
use SmartSea::Schema::Result::RuleClass qw/:all/;
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
    mount "/rest" => SmartSea::Browser->new(
    {
        schema => $schema,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0,
        js => 0,
        root => '/rest',
        fake_admin => 1
    })->to_app;
};

my %rule_classes = (
    &EXCLUSIVE_RULE => 'exclusive', 
    &INCLUSIVE_RULE => 'inclusive', 
    &MULTIPLICATIVE_RULE => 'multiplicative', 
    &ADDITIVE_RULE => 'additive', 
    &BOXCAR_RULE => 'boxcar', 
    &BAYESIAN_NETWORK_RULE => 'bayesian' );

for my $id (keys %rule_classes) {
    $schema->resultset('RuleClass')->new({id => $id, name => "rule class $id"})->insert;
    $schema->resultset('RuleSystem')->new({id => $id, rule_class => $id})->insert;
}

$schema->resultset('Dataset')->new({id => 1, name => "dataset"})->insert;

my $host = 'http://127.0.0.1';

my %column_tests = (
    op => {&EXCLUSIVE_RULE => 1, &INCLUSIVE_RULE => 1},
    value  => {&EXCLUSIVE_RULE => 1, &INCLUSIVE_RULE => 1},
    min_value => {&MULTIPLICATIVE_RULE => 1, &ADDITIVE_RULE => 1},
    max_value => {&MULTIPLICATIVE_RULE => 1, &ADDITIVE_RULE => 1},
    value_at_min => {&MULTIPLICATIVE_RULE => 1, &ADDITIVE_RULE => 1},
    value_at_max => {&MULTIPLICATIVE_RULE => 1, &ADDITIVE_RULE => 1},
    weight => {&MULTIPLICATIVE_RULE => 1, &ADDITIVE_RULE => 1, &BOXCAR_RULE => 1},
    boxcar_type => {&BOXCAR_RULE => 1},
    boxcar_x0 => {&BOXCAR_RULE => 1},
    boxcar_x1 => {&BOXCAR_RULE => 1},
    boxcar_x2 => {&BOXCAR_RULE => 1},
    boxcar_x3 => {&BOXCAR_RULE => 1},
    node => {&BAYESIAN_NETWORK_RULE => 1},
    state_offset => {&BAYESIAN_NETWORK_RULE => 1},
    );

test_psgi $app, sub {
    my $cb = shift;

    # create, read, update, and delete once a rule of each type
    for my $rule_system (sort keys %rule_classes) {
        #next unless $rule_classes{$rule_system} eq 'boxcar';
            
        my $res = $cb->(
            POST "$host/rest/rule?request=create", 
            [ 
              accept => 'json', dataset => 1, rule_system => $rule_system, 
              value => 2.5, 
              weight => 3 
            ]);

        for my $r ($schema->resultset('Rule')->all) {
            my $info = $r->columns_info;
            for my $col (sort keys %$info) {
                #say STDERR 'database: ',$col,' => ',($r->$col//'undef');
            }
        }
                
        $res = decode_json $res->content;

        for my $col (sort keys %column_tests) {
            if ($column_tests{$col}{$rule_system}) {
                ok(exists $res->{$col}, "rule class $rule_classes{$rule_system} implies $col");
                if ($col eq 'value') {
                    ok($res->{$col}{value} == 2.5, "value is what we set it to");
                }
                if ($col eq 'weight') {
                    ok($res->{$col}{value} == 3, "$rule_classes{$rule_system}: weight is what we set it to ");
                }
            } else {
                ok(not(exists $res->{$col}), "rule class $rule_classes{$rule_system} implies no $col");
            }
        }
    }

    for my $rule ($schema->resultset('Rule')->all) {
        my $res = $rule->read;
        #print STDERR Dumper $res;
        my $rule_system = $rule->rule_system->id;
        for my $col (sort keys %column_tests) {
            if ($column_tests{$col}{$rule_system}) {
                ok(exists $res->{$col}, "rule class $rule_classes{$rule_system} implies $col");
                if ($col eq 'value') {
                    ok($res->{value} == 2.5, "value is what we set it to");
                }
                if ($col eq 'weight') {
                    ok($res->{weight} == 3, "$rule_classes{$rule_system}: weight is what we set it to ");
                }
            } else {
                ok(not(exists $res->{$col}), "rule class $rule_classes{$rule_system} implies no $col");
            }
        }
    }
    
};

done_testing();
