use Modern::Perl;
use File::Basename;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Plack::Builder;
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use JSON;

use Data::Dumper;

use lib '.';
use Test::Helper;

use SmartSea::Core qw(:all);

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');
use_ok('SmartSea::Plans');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);
my $parser = XML::LibXML->new(no_blanks => 1);

my $service = SmartSea::Plans->new(
    {
        schema => $schema,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0,
        no_js => 1,
        fake_admin => 1
    });
my $app = $service->to_app;

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/plans");
    my $plans;
    eval {
        $plans = decode_json $res->content;
    };
    ok($plans->[0]{name} eq 'Data' && @{$plans->[0]{uses}[0]{layers}} == 0, "empty plans");
};

done_testing;
