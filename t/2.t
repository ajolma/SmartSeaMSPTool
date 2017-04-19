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

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

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

if (1) {
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(GET "/");
        my $parser = XML::LibXML->new(no_blanks => 1);
        my $dom;
        eval {
            $dom = $parser->load_xml(string => $res->content);
        };
        ok(!$@, "get root");
    };
    
    test_psgi $app, sub {
        my $cb = shift;
        my $res = $cb->(GET "/plans");
        my $plans;
        eval {
            $plans  = decode_json $res->content;
        };
        ok($plans->[0]{name} eq 'Data' && @{$plans->[0]{uses}[0]{layers}} == 0, "empty plans");
    };
}

# todo: REST API tests (todo REST API first)
# my $res = $cb->(PUT "/browser/plans?add", [name => 'test', id => 1]);
# PUT "/browser/plan:1", [name => 'test']
# etc

# classes

my $classes = {};
my $id = {};

for my $source (sort $schema->sources) {
    my $table = source2table($source);
    my $class = "SmartSea::Schema::Result::$source";
    my $attr = $class->attributes;
    my $parents = [];
    my $refs = [];
    my $parts = [];
    my $cols = [];
    for my $col (sort keys %$attr) {
        my $item = {col => $col};
        $item->{class} = source2table($attr->{$col}{source}) if $attr->{$col}{source};
        for my $key (keys %{$attr->{$col}}) {
            $item->{$key} = $attr->{$col}{$key};
        }
        next if $attr->{$col}{self_ref};
        next if $attr->{$col}{optional};
        if ($attr->{$col}{input} eq 'object') {
            push @$parts, $item;
            next;
        }
        if ($attr->{$col}{input} eq 'lookup') {
            if ($attr->{$col}{parent}) {
                push @$parents, $item;
            } else {
                push @$refs, $item;
            }
            next;
        }
        if ($attr->{$col}{required}) {
            $item->{value} = 1; # this should be based on the type of the col
            push @$cols, $item;
        }
    }
    $classes->{$table} = {
        parents => $parents,
        refs => $refs,
        parts => $parts,
        cols => $cols
    };
}

sub source2table {
    my $source = shift;
    $source =~ s/([a-z])([A-Z])/$1_$2/;
    $source =~ s/([A-Z])/lc($1)/ge;
    return $source;
}

my $links = {
    plan2dataset_extra => {classes => [qw/plan dataset/]},
    use_class2activity => {classes => [qw/use_class activity/]}
};

$service->{debug} = 0;

# test create and delete of objects of all classes
if (1) {for my $class (keys %$classes) {
    next if $classes->{$class}{embedded};
    #next unless $class eq 'rule_system';

    test_psgi $app, sub {
        my $cb = shift;

        my $res = create_object($cb, $class);
        #say STDERR $res->content;
        #pretty_print($res);
        
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
        #say STDERR $res->content;
        
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
done_testing();
exit;

$service->{debug} = 0;

# test links
test_psgi $app, sub {
    my $cb = shift;
    
    my $res = create_object($cb, 'dataset', {path => '1'});
    $res = create_object($cb, 'dataset', {id => 2, name => 'test2', path => '2'});
    $res = $cb->(POST "/browser/plan?save", [id => 1, name => 'test']);
    $res = $cb->(POST "/browser/plan:1/dataset", [submit => 'Create', extra_dataset => 2]);

    my @all = select_all($schema, 'tool', 'id,plan,dataset', 'plan2dataset_extra');
    for my $row (@all) {
        say STDERR "plan2dataset_extra table = @$row" if $service->{debug} > 1;
    }
    
    my ($n, $plan2dataset, $plan, $dataset) = ($#all+1, @{$all[0]});
    
    ok($n == 1 && $plan2dataset == 1 && $plan == 1 && $dataset == 2, "create plan to extra dataset link");

    $res = $cb->(POST "/browser/plan:1/dataset", [2 => 'Delete']);
    #pretty_print($res);

    @all = select_all($schema, 'tool', 'id,plan,dataset', 'plan2dataset_extra');

    ok(@all == 0, "delete the link");
    
};

$service->{debug} = 0;

test_psgi $app, sub {
    my $cb = shift;
    
    my $res = create_object($cb, 'use_class', {id => 2});
    $res = create_object($cb, 'activity');
    
    $res = $cb->(POST "/browser/use_class:2/activity", [submit => 'Create', activity => 1]);
    #pretty_print($res);

    my @all = select_all($schema, 'tool', 'id,use_class,activity', 'use_class2activity');
    
    my ($n, $id, $use_class, $activity) = ($#all+1, @{$all[0]});
    
    ok($n == 1 && $id == 1 && $use_class == 2 && $activity == 1, "create use_class to activity link");

    $res = $cb->(POST "/browser/use_class:2/activity", [1 => 'Delete']);
    #pretty_print($res);

    @all = select_all($schema, 'tool', 'id,plan,dataset', 'plan2dataset_extra');

    ok(@all == 0, "delete the link");
    
};

sub select_all {
    my ($schema, $db, $cols, $class) = @_;
    my @all;
    $schema->$db->storage->dbh_do(sub {
        my (undef, $dbh) = @_;
        my $sth = $dbh->prepare("SELECT $cols FROM $class");
        $sth->execute;
        while (my @a = $sth->fetchrow_array) {
            say STDERR "$cols from $class" if $service->{debug};
            push @all, \@a;
        }});
    return @all;
}

sub pretty_print {
    my $res = shift;
    my $parser = XML::LibXML->new(no_blanks => 1);
    my $dom = $parser->load_xml(string => $res->content);
    $pp->pretty_print($dom);
    print STDERR $dom->toString;
}

sub deps {
    my ($class, $dep) = @_;
    my $deps = $classes->{$class}{$dep};
    return @$deps;
}

sub attrs {
    my ($cb, $class, $attr) = @_;
    for my $ref (deps($class, 'refs')) {
        create_object($cb, $ref->{class});
        $attr->{$ref->{col}} = 1;
    }
    for my $col (deps($class, 'cols')) {
        $attr->{$col->{col}} = $col->{value};
    }
}

sub create_object {
    my ($cb, $class, $attr) = @_;
    my $url = '/browser';
    $id->{$class}++;
    my %attr = (name => 'test', id => $id->{$class});
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
        # what attrs part requires
        attrs($cb, $part->{class}, \%attr); 
    }
    if ($attr) { 
        for my $key (keys %$attr) {
            $attr{$key} = $attr->{$key};
        }
    }
    my @attr = map {$_ => $attr{$_}} keys %attr;
    $url = "$url/$class?save";
    say STDERR "POST $url @attr" if $service->{debug};
    return $cb->(POST $url, \@attr);
}

sub delete_object {
    my ($cb, $class) = @_;
    my $url = '/browser';
    my @attr = ($id->{$class} => 'Delete');
    $id->{$class}--;
    for my $parent (deps($class, 'parents')) {
        $url .= '/'.$parent->{class}.':1';
    }
    $url = "$url/$class?delete";
    say STDERR "POST $url @attr" if $service->{debug};
    my $ret = $cb->(POST $url, \@attr);
    for my $ref (deps($class, 'refs')) {
        delete_object($cb, $ref->{class});
    }
    for my $parent (deps($class, 'parents')) {
        delete_object($cb, $parent->{class});
    }
    return $ret;
}

done_testing();
