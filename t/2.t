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

use_ok('SmartSea::Schema');
use_ok('SmartSea::Object');
use_ok('SmartSea::Service');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

create_sqlite_schemas(read_postgresql_dump($path.'../schema.sql'));

my $schema = one_schema();

my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");

my $service = SmartSea::Service->new(
    {
        schema => $schema,
        data_dir => '',
        images => '',
        debug => 0,
        edit => 1,
        sequences => 0
    });
my $app = $service->to_app;

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/");
    #say STDERR $res->content;
    my $parser = XML::LibXML->new(no_blanks => 1);
    my $dom;
    eval {
        $dom = $parser->load_xml(string => $res->content);
    };
    ok(!$@, "get root");
    #$pp->pretty_print($dom);
    #print STDERR $dom->toString;
};

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/plans");
    #say STDERR $res->content;
    my $plans;
    eval {
        $plans  = decode_json $res->content;
    };
    ok($plans->[0]{name} eq 'Data' && @{$plans->[0]{uses}[0]{layers}} == 0, "empty plans");
    #print STDERR Dumper($plans);
};

# todo: REST API tests (todo REST API first)
# my $res = $cb->(PUT "/browser/plans?add", [name => 'test', id => 1]);
# PUT "/browser/plan:1", [name => 'test']
# etc

# classes

my $classes = {
    # these do not need other objects
    plan => {},
    activity => {},
    color_scale => {},
    ecosystem_component => {},
    layer_class=> {},
    pressure_category=> {},
    number_type=> {},
    op=> {},
    rule_class=> {},
    use_class=> {},
    data_model=> {},
    dataset=> {},
    license=> {},
    organization=> {},
    unit=> {}
};

# these need one or more other objects

$classes->{pressure_class} = {
    refs => [{col => 'category', class => 'pressure_category'}]
};

$classes->{pressure} = {
    parents => [{col => 'activity', 'class' => 'activity'}], 
    refs => [{col => 'pressure_class', 'class' => 'pressure_class'}],
    cols => [{col => 'range', value => 1}]
};

$classes->{impact} = {
    parents => [{col => 'pressure', class => 'pressure'}], 
    refs => [{col => 'ecosystem_component', class => 'ecosystem_component'}]
};

$classes->{layer} = {
    parents => [{col => 'use', class => 'use'}],
    refs => [
        {col => 'layer_class', class => 'layer_class'},
        {col => 'rule_class', class => 'rule_class'}
        ],
    parts => [{col => 'style', class => 'style'}],
};

$classes->{rule} = {
    parents => [{col => 'layer', class => 'layer'}],
    refs => [
        {col => 'op', class => 'op'},
        {col => 'number_type', class => 'number_type'},
        {col => 'r_dataset', class => 'dataset'}
        ]
};

$classes->{style} = {
    embedded => 1,
    refs => [{col => 'color_scale', class => 'color_scale'}]
};

$classes->{use} = {
    parents => [{col => 'plan', class => 'plan'}], 
    refs => [{col => 'use_class', class => 'use_class'}]
};

my $links = {
    plan2dataset_extra => {classes => [qw/plan dataset/]},
    use_class2activity => {classes => [qw/use_class activity/]}
};

$service->{debug} = 0;

# test create and delete of objects of all classes
if (1) {for my $class (keys %$classes) {
    next if $classes->{$class}{embedded};

    test_psgi $app, sub {
        my $cb = shift;

        my $res = create_object($cb, $class);
        #say STDERR $res->content;
        
        my $parser = XML::LibXML->new(no_blanks => 1);
        my $dom;
        eval {
            $dom = $parser->load_xml(string => $res->content);
        };
        ok(!$@, "create $class ".$@);
        #$pp->pretty_print($dom);
        #print STDERR $dom->toString;
    };
    
    test_psgi $app, sub {
        my $cb = shift;

        my $res = delete_object($cb, $class);
        
        my $parser = XML::LibXML->new(no_blanks => 1);
        my $dom;
        eval {
            $dom = $parser->load_xml(string => $res->content);
        };
        ok(!$@, "delete $class ".$@);
        #$pp->pretty_print($dom);
        #print STDERR $dom->toString;
    };
}}

# test links
test_psgi $app, sub {
    my $cb = shift;
    
    my $res = create_object($cb, 'dataset', {path => '1'});
    $res = create_object($cb, 'dataset', {id => 2, name => 'test2', path => '2'});
    #$res = $cb->(GET "/browser/datasets");
    
    #$res = create_object($cb, 'plan');
    #say STDERR $res->content;
    
    $res = $cb->(POST "/browser/plan?create", [id => 1, name => 'test']);
    #$res = $cb->(GET "/browser/plan:1");

    $res = $cb->(POST "/browser/plan:1/plan2dataset_extra", [submit => 'Add', extra_dataset => 2]);

    my ($n, $plan2dataset, $plan, $dataset);
    $schema->tool->storage->dbh_do(
        sub {
            my ($storage, $dbh) = @_;
            my $sth = $dbh->prepare("SELECT id,plan,dataset FROM plan2dataset_extra");
            $sth->execute;
            $n = 0;
            while (my @a = $sth->fetchrow_array) {
                ($plan2dataset, $plan, $dataset) = @a;
                #say STDERR "Plan to Dataset: $id: $plan -> $dataset";
                ++$n;
            }
        });
    
    #my $parser = XML::LibXML->new(no_blanks => 1);
    #my $dom;
    #eval {
    #    $dom = $parser->load_xml(string => $res->content);
    #};
    ok($plan2dataset == 1 && $plan == 1 && $dataset == 2, "create plan to extra dataset link");
    #$pp->pretty_print($dom);
    #print STDERR $dom->toString;
};

sub deps {
    my ($class, $dep) = @_;
    my $deps = $classes->{$class}{$dep};
    return @$deps if $deps;
    return ();
}

sub create_object {
    my ($cb, $class, $attr) = @_;
    my $url = '/browser';
    my %attr = (name => 'test', id => 1);
    for my $parent (deps($class, 'parents')) {
        create_object($cb, $parent->{class});
        $url .= '/'.$parent->{class}.':1';
    }
    for my $ref (deps($class, 'refs')) {
        create_object($cb, $ref->{class});
        $attr{$ref->{col}} = 1;
    }
    for my $col (deps($class, 'cols')) {
        $attr{$col->{col}} = $col->{value};
    }
    for my $part (deps($class, 'parts')) {
        $attr{$part->{col}.'_is'} = 1;
    }
    if ($attr) { 
        for my $key (keys %$attr) {
            $attr{$key} = $attr->{$key};
        }
    }
    my @attr = map {$_ => $attr{$_}} keys %attr;
    say STDERR "POST $url/$class?create @attr";
    return $cb->(POST "$url/$class?create", \@attr);
}

sub delete_object {
    my ($cb, $class) = @_;
    my $url = '/browser';
    my @attr = (1 => 'Delete');
    for my $parent (deps($class, 'parents')) {
        $url .= '/'.$parent->{class}.':1';
    }
    #say STDERR "POST $url/$class?delete @attr";
    my $ret = $cb->(POST "$url/$class?delete", \@attr);
    for my $ref (deps($class, 'refs')) {
        delete_object($cb, $ref->{class});
    }
    for my $parent (deps($class, 'parents')) {
        delete_object($cb, $parent->{class});
    }
    return $ret;
}

done_testing();

__DATA__
for my $class (keys %$classes) {
    next if $classes->{$class}{parents};

    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(POST "/browser/$class?create", [name => 'test', id => 1]);
        my $parser = XML::LibXML->new(no_blanks => 1);
        my $dom;
        eval {
            $dom = $parser->load_xml(string => $res->content);
        };
        ok(!$@, "create $class");
        #$pp->pretty_print($dom);
        #print STDERR $dom->toString;
    };
    
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(POST "/browser/$class?delete", [1 => 'Delete']);
        my $parser = XML::LibXML->new(no_blanks => 1);
        my $dom;
        eval {
            $dom = $parser->load_xml(string => $res->content);
        };
        ok(!$@, "delete $class");
        #$pp->pretty_print($dom);
        #print STDERR $dom->toString;
    };
}
