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

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/?accept=json");
    for my $i (@{decode_json $res->content}) {
        my $class = $i->{class};
        #next unless $i->{class} eq 'impact_layer';
        
        crud($cb, $i->{class});

        my $schema = get_schema($cb, $class);
        next unless $schema->{related};
        
        my $object = create_object($cb, $class);
        my $id = $object->{id}{value};

        test_create_related($cb, $schema, $class, $object);

        # update related

        for my $relationship (keys %{$schema->{related}}) {
            my $rel = $schema->{related}{$relationship};
            next if defined $rel->{edit} && $rel->{edit} == 0; # relationship is purely computed
            next if $rel->{stop_edit};

            my %data = set_data($cb, $rel->{source});
            $data{relationship} = $relationship;
            my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
            #say STDERR "$class -> $relationship";
            my $res = $cb->(POST "/$class:$id/$rel->{source}?request=create&$param&accept=json");
            my $rel_obj = decode_json $res->content;
            #print STDERR Dumper $rel_obj;
            $object = read_object($cb, $class, $id);

            $service->{debug} = 0;
            $res = $cb->(POST "/$class:$id/$rel->{source}:$rel_obj->{id}{value}?request=update&$param&accept=json");
            $object = read_object($cb, $class, $id);
            #print STDERR Dumper $object;
            $rel_obj = decode_json $res->content;
            #print STDERR Dumper $object->{related};
            #print STDERR Dumper $rel_obj;
        }

        # delete related

        for my $relationship (keys %{$schema->{related}}) {
            my $rel = $schema->{related}{$relationship};
            next if defined $rel->{edit} && $rel->{edit} == 0; # relationship is purely computed

            if ($rel->{stop_edit}) {
                # the related object needs to exist
            
                my $rel_obj = create_object($cb, $rel->{source});
                my $res = $cb->(POST "/$class:$id/$rel->{source}:$rel_obj->{id}{value}?request=create&accept=json");
            }

            $object = read_object($cb, $class, $id);
            #say STDERR "$class -> $relationship";
            #print STDERR Dumper $object;
            next unless $object->{related}{$relationship}{objects};
            my @related = @{$object->{related}{$relationship}{objects}};
            my $delete_id = $related[0];

            $res = $cb->(POST "/$class:$id/$rel->{source}:$delete_id?request=delete&accept=json");
            my $rel_obj = decode_json $res->content;

            $object = read_object($cb, $class, $id);
            # deleted should not be in related
            # unless stop_edit, the related object should not exist anymore
            
            #print STDERR Dumper $object->{related};
            #print STDERR Dumper $rel_obj;
        }
        
        #exit;
    }
};

sub test_create_related {
    my ($cb, $schema, $class, $object) = @_;
    my $id = $object->{id}{value};
    for my $relationship (keys %{$schema->{related}}) {
        my $rel = $schema->{related}{$relationship};
        next if defined $rel->{edit} && $rel->{edit} == 0; # relationship is purely computed
        
        if ($rel->{stop_edit}) {
            # the related object needs to exist
            
            my $rel_obj = create_object($cb, $rel->{source});
            my $res = $cb->(POST "/$class:$id/$rel->{source}:$rel_obj->{id}{value}?request=create&accept=json");
            $rel_obj = decode_json $res->content;
            $object = read_object($cb, $class, $id);
            
            my %related = map {$_=>1} @{$object->{related}{$relationship}{objects}};
            ok($related{$rel_obj->{id}{value}}, "link from $class to $relationship");
        } else {
            # the related object can be created
            
            my %data = set_data($cb, $rel->{source});
            $data{relationship} = $relationship;
            my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
            my $res = $cb->(POST "/$class:$id/$rel->{source}?request=create&$param&accept=json");
            my $rel_obj = decode_json $res->content;
            $object = read_object($cb, $class, $id);
            
            my %related = map {$_=>1} @{$object->{related}{$relationship}{objects}};
            ok($related{$rel_obj->{id}{value}}, "link from $class to new $relationship");
        }
    }
}

sub crud {
    my ($cb, $class) = @_;
    my $schema = get_schema($cb, $class);
    # create
    my %data;
    for my $key (keys %$schema) {
        next if $key eq 'related';
        next unless $schema->{$key}{not_null};
        next if $schema->{$key}{is_part} || $schema->{$key}{is_superclass};
        next if $schema->{$key}{source};
        if ($schema->{$key}{data_type} eq 'text') {
            $data{$key} = 'x';
        } else {
            $data{$key} = 1;
        }
    }
        
    my $object = create_object($cb, $class, \%data);
    my $id = $object->{id} ? $object->{id}{value} : $object->{super}{value};
        
    for my $key (keys %$schema) {
        next unless exists $data{$key};
        ok($object->{$key}{value} eq $data{$key}, "'$object->{$key}{value}' eq '$data{$key}' after create $class");
    }

    # update
    for my $key (keys %$schema) {
        next unless exists $data{$key};
        if ($schema->{$key}{data_type} eq 'text') {
            $data{$key} = 'y';
        } else {
            $data{$key} = 2;
        }
    }
    my $param = join(q{&}, map{qq{$_=$data{$_}}} keys %data);
    my $res = $cb->(POST "/$class:$id?request=update&$param&accept=json");
    $object = decode_json $res->content;
    for my $key (keys %$schema) {
        next unless exists $data{$key};
        ok($object->{$key}{value} eq $data{$key}, "'$object->{$key}{value}' eq '$data{$key}' after update $class");
    }
    
    # delete
    $res = $cb->(POST "/$class:$id?request=delete&$param&accept=json");
    my $result = decode_json $res->content;
    ok($result->{result} eq 'ok', "delete $class");
}

sub unique {
    state $seed = 1;
    ++$seed;
    return $seed;
}

sub get_schema {
    my ($cb, $class) = @_;
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
        next if $key eq 'related';
        next unless $schema->{$key}{not_null};
        if ($schema->{$key}{is_part} || $schema->{$key}{is_superclass}) {
            %data = (%data, set_data($cb, $schema->{$key}{source}));
        } elsif ($schema->{$key}{source}) {
            if (!$data{$key}) {
                my $object = create_object($cb, $schema->{$key}{source});
                $data{$key} = $object->{id}{value};
            }
        } elsif ($schema->{$key}{data_type} eq 'text') {
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
    my $res = $cb->(POST "/$class?request=add&$param&accept=json");
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

done_testing;
