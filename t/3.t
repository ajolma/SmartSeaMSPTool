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
        js => 0,
        fake_admin => 1
    });
my $app = $service->to_app;

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/?accept=json");
    for my $i (@{decode_json $res->content}) {
        my $class = $i->{class};
        #next unless $i->{class} eq 'rule_class';
        
        crud($cb, $class);

        my $schema = get_schema($cb, $class);
        next unless $schema->{related};
        
        my $object = create_object($cb, $class);
        my $id = $object->{id}{value};

        test_create_related($cb, $schema, $class, $object);

        # update related

        for my $relationship (keys %{$schema->{related}}) {
            my $rel = $schema->{related}{$relationship};
            next unless $rel->{edit}; # relationship is purely computed
            next if $rel->{stop_edit};

            my %data = set_data($cb, $rel->{class});
            $data{relationship} = $relationship;
            my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
            my $res = $cb->(POST "/$class:$id/$relationship?request=create&$param&accept=json");
            my $rel_obj = decode_json $res->content;
            $object = read_object($cb, $class, $id);

            $res = $cb->(POST "/$class:$id/$relationship:$rel_obj->{id}{value}?request=update&$param&accept=json");
            $object = read_object($cb, $class, $id);
        }

        # delete related

        for my $relationship (keys %{$schema->{related}}) {
            my $rel = $schema->{related}{$relationship};
            next unless $rel->{edit}; # relationship is purely computed

            if ($rel->{stop_edit}) {
                # the related object needs to exist
                my $rel_obj = create_object($cb, $rel->{class});
                my $res = $cb->(POST "/$class:$id/$rel->{class}:$rel_obj->{id}{value}?request=create&accept=json");
            }

            $object = read_object($cb, $class, $id);
            next unless $object->{related}{$relationship}{objects};
            my @related = @{$object->{related}{$relationship}{objects}};
            my $delete_id = $related[0];

            $res = $cb->(POST "/$class:$id/$rel->{class}:$delete_id?request=delete&accept=json");
            my $rel_obj = decode_json $res->content;

            $object = read_object($cb, $rel->{class}, $id);
            # deleted should not be in related
            # unless stop_edit, the related object should not exist anymore
        }
        
        #exit;
    }
};

sub test_create_related {
    my ($cb, $schema, $class, $object) = @_;
    my $id = $object->{id}{value};
    for my $relation (keys %{$schema->{related}}) {
        my $rel = $schema->{related}{$relation};
        next unless $rel->{edit}; # relationship is purely computed
        
        if ($rel->{stop_edit}) {
            # the related object needs to exist
            
            my $rel_obj = create_object($cb, $rel->{class});
            my $res = $cb->(POST "/$class:$id/$relation:$rel_obj->{id}{value}?request=create&accept=json");
            $rel_obj = decode_json $res->content;
            $object = read_class($cb, $class, $id, $relation);
            
            ok(@$object == 1, "link from $class to existing $relation");
        } else {
            # the related object can be created
            
            my %data = set_data($cb, $rel->{class});
            $data{relationship} = $relation;
            my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
            my $res = $cb->(POST "/$class:$id/$relation?request=create&$param&accept=json");
            my $rel_obj = decode_json $res->content;
            $object = read_class($cb, $class, $id, $relation);
            #print STDERR Dumper $object;
            
            ok(@$object == 1, "link from $class to new $relation");
        }
    }
}

sub crud {
    my ($cb, $class) = @_;
    my $schema = get_schema($cb, $class);
    #print STDERR Dumper $schema;
    # create
    my %data;
    for my $key (keys %$schema) {
        next unless ref $schema->{$key};
        next if $key eq 'cookie';
        next if $key eq 'related';
        next if $key eq 'id';
        next if $key eq 'owner';
        next if $schema->{$key}{is_part} || $schema->{$key}{is_superclass};
        next if $schema->{$key}{source};
        if ($schema->{$key}{data_type} && $schema->{$key}{data_type} eq 'text') {
            $data{$key} = 'x';
        } else {
            $data{$key} = 1;
        }
    }
        
    my $object = create_object($cb, $class, \%data);
    my $id = $object->{id} ? $object->{id}{value} : $object->{super}{value};
        
    for my $key (keys %$schema) {
        next unless ref $schema->{$key};
        next if $key eq 'related';
        next if $key eq 'id';
        next if $key eq 'owner';
        next unless exists $data{$key};
        ok($object->{$key}{value} eq $data{$key}, "'$object->{$key}{value}' eq '$data{$key}' ($key) after create $class");
    }

    # update
    for my $key (keys %$schema) {
        next unless ref $schema->{$key};
        next if $key eq 'related';
        next if $key eq 'id';
        next if $key eq 'owner';
        next unless exists $data{$key};
        if ($schema->{$key}{data_type} && $schema->{$key}{data_type} eq 'text') {
            $data{$key} = 'y';
        } else {
            $data{$key} = 2;
        }
    }
    my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
    my $res = $cb->(POST "/$class:$id?request=update&$param&accept=json");
    $object = decode_json $res->content;
    for my $key (keys %$schema) {
        next unless ref $schema->{$key};
        next if $key eq 'related';
        next if $key eq 'id';
        next if $key eq 'owner';
        next unless exists $data{$key};
        ok($object->{$key}{value} eq $data{$key}, "'$object->{$key}{value}' eq '$data{$key}' ($key) after update $class");
    }
    
    # delete
    $res = $cb->(POST "/$class:$id?request=delete&$param&accept=json");
    my $result = decode_json $res->content;
    ok($result->{result} eq 'ok', "delete $class");
    my $count = 0;
    for my $o ($service->{schema}->resultset(table2source($class))->all) {
        ++$count if $o->id == $id;
    }
    ok($count == 0, "delete $class");
}

sub unique {
    state $seed = 1;
    ++$seed;
    return $seed;
}

sub get_schema {
    my ($cb, $class) = @_;
    $class = source2class($class);
    my $res = $cb->(GET "/$class:0?accept=json");
    #say STDERR $res->content;
    return decode_json $res->content;
}

sub set_data {
    my ($cb, $class, $data) = @_;
    my $schema = get_schema($cb, $class);
    my %data;
    %data = %$data if $data;
    for my $key (keys %$schema) {
        next unless ref $schema->{$key};
        next unless $schema->{$key}{not_null};
        if ($schema->{$key}{is_part} || $schema->{$key}{is_superclass}) {
            %data = (%data, set_data($cb, $schema->{$key}{source}));
        } elsif ($schema->{$key}{source}) {
            if (!$data{$key}) {
                my $object = create_object($cb, source2class($schema->{$key}{source}));
                $data{$key} = $object->{id}{value};
            }
        } elsif ($schema->{$key}{data_type} && $schema->{$key}{data_type} eq 'text') {
            $data{$key} //= unique();
        } else {
            $data{$key} //= unique();
        }
    }
    return %data;
}

sub create_object {
    my ($cb, $class, $data) = @_;
    #say STDERR '  create ',$class;
    my %data = set_data($cb, $class, $data);
    my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
    #say STDERR $param;
    my $res = $cb->(POST "/$class?request=create&$param&accept=json");
    #say STDERR $res->content;
    my $object = decode_json $res->content;
    $object->{id}{value} //= $object->{super}{value};
    #say STDERR "  $class id = ",$object->{id}{value};
    return $object;
}

sub read_object {
    my ($cb, $class, $id) = @_;
    my $res = $cb->(GET "/$class:$id?accept=json");
    my $object = decode_json $res->content;
    $object->{id}{value} //= $object->{super}{value};
    return $object;
}

sub read_class {
    my ($cb, $class, $id, $related) = @_;
    my $res = $cb->(GET "/$class:$id/$related?accept=json");
    #say STDERR $res->content;
    my $object = decode_json $res->content;
    return $object;
}

done_testing;
