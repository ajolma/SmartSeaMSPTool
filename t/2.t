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
use_ok('SmartSea::Browser');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);
my $client = {schema => $schema, user => 'guest'};
my $parser = XML::LibXML->new(no_blanks => 1);

my $service = SmartSea::Browser->new(
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

my %unique = (
    name => 1,
    plan => 1,
    use => 1,
    activity => 1
    );

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/");
    my $dom;
    eval {
        $dom = $parser->load_xml(string => $res->content);
    };
    ok(!$@, "get browser list");
    for my $a ($dom->documentElement->findnodes('//a')) {
        my $href = $a->getAttribute('href');
        next unless $href && $href ne '';
        next if $href =~ /2/;
     
        $res = $cb->(GET $href);
        eval {
            $parser->load_xml(string => $res->content);
        };

        my $class = $href;
        $class =~ s/^\///;
        
        #next unless $class eq 'layer';
        #$service->{debug} = 2;

        test_creating_object($cb, {source => table2source($class)});
        
        $res = $cb->(GET "$href:1");
        eval {
            $parser->load_xml(string => $res->content);
        };
        say STDERR $res->content if $@;
        ok(!$@, "GET $href:1");
    }
};

sub create_required_objects {
    my ($cb, $obj) = @_;
    my $columns = $obj->columns;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        next if $meta->{is_superclass} && $meta->{is_part};
        next unless $meta->{is_foreign_key} && $meta->{not_null};
        
        my $class = source2table($meta->{source});
        my $res = $cb->(GET '/'.$class.'?accept=json');
        my $data = decode_json $res->content;
        if (@$data) {
            #print STDERR Dumper $data;
        } else {
            test_creating_object($cb, {source => $meta->{source}});
        }
        
    }
}

sub add_required_data {
    my ($columns) = @_;
    my %post;
    for my $column (sort keys %$columns) {
        my $meta = $columns->{$column};
        if ($meta->{columns}) {
            %post = (%post,add_required_data($meta->{columns}));
        } elsif ($meta->{not_null}) {
            if ($unique{$column}) {
                $post{$column} = $unique{$column};
                $unique{$column} += 1;
            } else {
                $post{$column} = 1;
            }
        }
    }
    return %post;
}

sub test_creating_object {
    my ($cb, $args) = @_;

    my $class = source2table($args->{source});
    my $obj = SmartSea::Object->new($args, $client);
    my $columns = $obj->columns;

    create_required_objects($cb, $obj);

    my %post = (submit => 'Add',add_required_data($columns));

    for my $col (sort keys %post) {
        #say STDERR "post: $col => $post{$col}";
    }

    #say STDERR $class;
    #$service->{debug} = 2;
    my $res = $cb->(POST '/'.$class, \%post);
    #say STDERR $res->content;
    eval {
        $parser->load_xml(string => $res->content);
    };
    ok(!$@, "POST /$class {submit => Add}");
    pretty_print_XML($res->content) if $@;
    #pretty_print_XML($res->content) if $class eq 'layer';
    #exit;
}
    
done_testing;
