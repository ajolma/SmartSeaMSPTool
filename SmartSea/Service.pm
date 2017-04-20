package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Scalar::Util 'blessed';
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Schema;
use SmartSea::Object;
use Data::Dumper;
use Data::GUID;

use parent qw/Plack::Component/;

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    $self->{data_dir} .= '/' unless $self->{data_dir} =~ /\/$/;
    $self->{images} .= '/' unless $self->{images} =~ /\/$/;
    $self = Plack::Component->new($self);
    unless ($self->{schema}) {
        my $dsn = "dbi:Pg:dbname=$self->{dbname}";
        $self->{schema} = SmartSea::Schema->connect(
            $dsn,
            $self->{user},
            $self->{pass},
            { on_connect_do => ['SET search_path TO tool,data,public'] });
    }
    $self->{sequences} = 1 unless defined $self->{sequences};
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    if ($self->{debug} > 2) {
        for my $key (sort keys %$env) {
            say STDERR "$key => $env->{$key}";
        }
    }
    my $ret = common_responses({}, $env);
    return $ret if $ret;
    my $request = Plack::Request->new($env);
    my $cookies = $request->cookies;
    for my $cookie (sort keys %$cookies) {
        #say STDERR "cookie: $cookie => $cookies->{$cookie}";
    }
    my $user = $env->{REMOTE_USER} // 'guest';
    $self->{edit} = 1 if $user eq 'ajolma';
    $self->{cookie} = $cookies->{SmartSea} // DEFAULT;
    $self->{parameters} = $request->parameters;
    $self->{uri} = $env->{REQUEST_URI};
    $self->{method} = $env->{REQUEST_METHOD}; # GET, PUT, POST, DELETE
    $self->{origin} = $env->{HTTP_ORIGIN};
    $self->{uri} =~ s/\/$//;
    my @path = split /\//, $self->{uri};
    say STDERR "remote user is $user" if $self->{debug};
    say STDERR "cookie: $self->{cookie}" if $self->{debug};
    say STDERR "uri: $self->{uri}" if $self->{debug};
    say STDERR "path: @path, ",scalar(@path)," items" if $self->{debug};
    my @base;
    while (@path) {
        my $step = shift @path;
        push @base, $step;
        return $self->plans() if $step eq 'plans';
        return $self->impact_network() if $step eq 'impact_network';
        return $self->pressure_table() if $step eq 'pressure_table';
        return $self->legend(\@path) if $step =~ /^legend/;
        if ($step eq 'browser') {
            $self->{base_uri} = join('/', @base);
            say STDERR "base_uri: $self->{base_uri}" if $self->{debug};
            return $self->object_editor(\@path);
        }
    }
    @path = split /\//, $self->{uri};
    my $uri = '';
    for my $step (@path) {
        $uri .= "$step/";
        last if $step eq 'core' or $step eq 'core_auth';
    }
    my @l;
    push @l, (
        [li => a(link => 'plans', url  => $uri.'plans')],
        [li => a(link => 'browser', url  => $uri.'browser')],
        [li => a(link => 'impact_network', url  => $uri.'impact_network')],
        [li => a(link => 'pressure table', url  => $uri.'pressure_table')]
    );
    return html200({}, SmartSea::HTML->new(html => [body => [ul => \@l]])->html);
}

# todo: sub rest
# which responds to url, method
# how to get the base_uri?

sub legend {
    my ($self, $oids) = @_;

    my $layer = SmartSea::Layer->new({
        schema => $self->{schema},
        trail => $self->{parameters}{layer}});

    my $image = $layer->{duck} ?
        $layer->{style}->legend({
            unit => $layer->unit,
            font => '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            font_size => 10,
            width => 200, # layout.css.right.width
            height => 140,
            symbology_width => 50}) 
        :
        GD::Image->new('/usr/share/icons/cab_view.png');
    
    return [ 200, 
             ['Content-Type' => 'image/png', 'Access-Control-Allow-Origin' => '*'], 
             [$image->png] ];
}

sub plans {
    my ($self) = @_;
    my $schema = $self->{schema};
    my $plans = $schema->resultset('Plan')->array_of_trees;
    
    # two pseudo plans, these will be shown as uses in all real plans
    
    push @$plans, { 
        name => 'Data', 
        id => 0, # reserved plan id, see msp.js and Layer.pm
        uses => [{
            name => 'Data', 
            id => 0, # reserved use_class id, see msp.js and Layer.pm
            layers => $schema->resultset('Dataset')->layers }]
    };

    push @$plans, {
        name => 'Ecosystem',
        id => 1, # reserved plan id, see msp.js and Layer.pm
        uses => [{
            name => 'Ecosystem',
            id => 1, # reserved use_class id, see msp.js and Layer.pm
            layers => $schema->resultset('EcosystemComponent')->layers }]
    };
        
    # This is the first request made by the App, thus set the cookie
    # if there is not one. The cookie is only for the duration the
    # browser is open.

    my $header = {
        'Access-Control-Allow-Origin' => $self->{origin},
        'Access-Control-Allow-Credentials' => 'true'
    };
    if ($self->{cookie} eq DEFAULT) {
        my $guid = Data::GUID->new;
        my $cookie = $guid->as_string;
        $header->{'Set-Cookie'} = "SmartSea=$cookie; httponly; Path=/";
    } else {

        # Cookie already set, reset changes, i.e., delete temporary
        # rules.  Above we give the default ones, this makes sure
        # temporary ones are not used for WMTS. Note that the rules
        # are left in the table and should be cleaned regularly based
        # on the "made" column.

        eval {
            for my $rule ($schema->resultset('Rule')->search({ cookie => $self->{cookie} })) {
                $rule->delete;
            }
        };
        say STDERR 'Error: '.$@ if $@;

    }
    return json200($header, $plans);
}

sub impact_network {
    my $self = shift;
    my @nodes;
    my @edges;
    $self->{schema}->resultset('Activity')->impact_network(\@nodes, \@edges);
    my %elements = (nodes => \@nodes, edges => \@edges);
    return json200({}, \%elements);
}

sub object_editor {
    my ($self, $oids) = @_;

    my $url = $self->{base_uri}.'/';
    unless (@$oids) {
        my @path = split /\//, $self->{base_uri};
        pop @path;
        my @body = a(link => 'Up', url => join('/', @path));
        my @li;
        for my $source (sort $self->{schema}->sources) {
            next if $source =~ /2/;
            my $lc = $source;
            $lc =~ s/([a-z])([A-Z])/$1_$2/;
            push @li, [li => a(link => SmartSea::Object::plural($source), url => $url.lc($lc))]
        }
        push @body, [ul=>\@li];
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    }

    # CRUD: 
    # create is one-step only for links, otherwise edit (without id) + save, 
    # read is default, 
    # update may create, and is known as edit + save
    # update is allowed only on rules and it is not a real update but a copy identified with cookie
    # delete does not do deep

    my %parameters = (request => 'read');
    
    my ($oid, $request) = split /\?/, $oids->[$#$oids];
    $oids->[$#$oids] = $oid;
    $parameters{request} = lc($request) if $request;
    
    # $self->{parameters} is a multivalue hash
    # we may have both object => command and object => id
    for my $key (sort keys %{$self->{parameters}}) {
        for my $value ($self->{parameters}->get_all($key)) {
            if ($key eq 'submit' && $value =~ /^Compute/) {
                $parameters{request} = 'edit';
                $parameters{compute} = $value;
                last;
            }
            $value = decode utf8 => $value;
            my $done = 0;
            for my $request (qw/create edit save delete remove/) {
                if (lc($value) eq $request) {
                    $parameters{request} = $request;
                    $parameters{request} = 'delete' if $request eq 'remove';
                    if ($parameters{request} eq 'delete') {
                        $parameters{id} = $key;
                    } else {
                        $parameters{$request} = $key;
                    }
                    $done = 1;
                    last;
                }
            }
            next if $done;
            if ($value eq 'NULL') {
                $parameters{$key} = undef;
            } else {
                $parameters{$key} = $value;
            }
        }
    }

    if ($self->{debug} > 1) {
        for my $p (sort keys %parameters) {
            say STDERR "$p => ".(defined($parameters{$p})?$parameters{$p}:'undef') ;
        }
    }

    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };

    my @body = [p => a(link => 'All classes', url => $self->{base_uri})];

    if ($parameters{request} eq 'read') {
        $self->read_object($oids, \@body);
        return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
        
    } elsif ($parameters{request} eq 'update') {
        return http_status($header, 403) if $self->{cookie} eq DEFAULT; # forbidden
        my $obj = SmartSea::Object->new({oid => $oids->[0], url => $self->{base_uri}}, $self);
        return http_status($header, 400) unless $obj->{object} && $obj->{source} eq 'Rule'; # bad request
        
        my $cols = $obj->{object}->values;
        $cols->{value} = $parameters{value};
        $cols->{cookie} = $self->{cookie};
        $cols->{made} = \['current_timestamp'];
        eval {
            $obj = $obj->{rs}->update_or_new($cols, {key => 'primary'});
            $obj->insert unless $obj->in_storage;
        };
        say STDERR "error: $@" if $@;
        return http_status($header, 500) if $@;
        return json200($header, {object => $obj->as_hashref_for_json});

    }

    return return http_status($header, 403) unless $self->{edit};

    my ($source, $id) = split /:/, $oids->[$#$oids];
    $id //= $parameters{id};
    my $obj = SmartSea::Object->new({source => $source, id => $id, url => $self->{base_uri}}, $self);
    return http_status($header, 400) unless $obj;

    $url = $self->{uri};
    $url =~ s/\?.*$//;

    if ($parameters{request} eq 'create') {
        $self->edit_object($obj, $oids, \%parameters, $url, \@body);
        
    } elsif ($parameters{request} eq 'delete') {
        my $error = $obj->delete($oids, $#$oids, \%parameters);
        push @body, error_message($error) if $error;
        $self->read_object($oids, \@body);
        
    } elsif ($parameters{request} eq 'save') {
        my $error = $obj->save($oids, $#$oids, \%parameters);
        if ($error) {
            push @body, error_message($error);
            $self->edit_object($obj, $oids, \%parameters, $url, \@body);
        } else {
            $self->read_object($oids, \@body);
        }
        
    } elsif ($parameters{request} eq 'edit') {
        $self->edit_object($obj, $oids, \%parameters, $url, \@body);
        
    } else {
        return http_status($header, 400);
    }

    return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
    
}

sub read_object {
    my ($self, $oids, $body) = @_;
    my $obj = SmartSea::Object->new({oid => $oids->[0], url => $self->{base_uri}}, $self);
    if ($obj) {
        push @$body, [ul => [li => $obj->li($oids, 0)]];
    } else {
        push @$body, [p => {style => 'color:red'}, $@];
    }
}

sub edit_object {
    my ($self, $obj, $oids, $parameters, $url, $body) = @_;
    my @form = $obj->form($oids, $#$oids, $parameters);
    if (@form) {
        push @$body, [form => {action => $url, method => 'POST'}, @form];
    } else {
        # object can be created with supplied information
        my $error = $obj->create($oids, $parameters);
        push @$body, error_message($error) if $error;
        $self->read_object($oids, $body);
    }
}

sub error_message {
    my $error = shift;
    return [p => {style => 'color:red'}, $error];
}

sub pressure_table {
    my ($self) = @_;
    my $body = $self->{schema}->resultset('Pressure')->table(
        $self->{schema},
        $self->{parameters},
        $self->{edit},
        $self->{uri}
        );
    return html200({}, SmartSea::HTML->new(html => [body => $body])->html);
}

1;
