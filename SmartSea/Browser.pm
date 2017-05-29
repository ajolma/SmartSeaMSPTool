package SmartSea::Browser;
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
    $self = Plack::Component->new($self);
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
    $self->{accept} = $request->headers->header('Accept') // '';
    $self->{json} = $self->{accept} eq 'application/json';
    $self->{user} = $env->{REMOTE_USER} // 'guest';
    $self->{user} = 'ajolma' if $self->{fake_admin};
    $self->{admin} = $self->{user} eq 'ajolma';
    $self->{cookie} = $request->cookies->{SmartSea} // DEFAULT;
    $self->{parameters} = $request->parameters;
    $self->{uri} = $env->{REQUEST_URI};
    $self->{method} = $env->{REQUEST_METHOD}; # GET, PUT, POST, DELETE
    $self->{origin} = $env->{HTTP_ORIGIN};
    $self->{uri} =~ s/\/$//;
    my @path = split /\//, $self->{uri};
    say STDERR "accept $self->{accept}" if $self->{debug};
    say STDERR "remote user is $self->{user}" if $self->{debug};
    say STDERR "cookie: $self->{cookie}" if $self->{debug};
    say STDERR "uri: $self->{uri}" if $self->{debug};
    say STDERR "path: @path" if $self->{debug};
    my @base;
    while (@path) {
        my $step = shift @path;
        push @base, $step;
        last if $step eq 'browser';
    }
    $self->{base_uri} = join('/', @base);
    return $self->object_editor(SmartSea::OIDS->new(\@path));
}

sub object_editor {
    my ($self, $oids) = @_;
    
    my $schemas = $self->{table_postfix} // '';
    $schemas =~ s/^_//;
    my $footer = [p => {style => 'font-size:0.8em'}, "Schema set = $schemas. User = $self->{user}."];

    my $url = $self->{uri}.'/';
    if ($oids->is_empty) {
        my @body = a(link => 'Up', url => $self->{root_url});
        my @li;
        for my $source (sort $self->{schema}->sources) {
            my $table = source2table($source);
            push @li, [li => a(link => SmartSea::Object::plural($source), url => $url.$table)]
        }
        push @body, [ul=>\@li];
        push @body, $footer;
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    }

    # CRUD: 
    # create is one-step only for links, otherwise edit (without id) + save, 
    # read is default, 
    # update may create, and is known as edit + save
    # update is allowed only on rules and it is not a real update but a copy identified with cookie
    # delete does not do deep

    my %parameters = (request => $oids->request // 'read');
    
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
            for my $request (qw/add create edit save delete remove/) {
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
            say STDERR "$p => '".(defined($parameters{$p})?$parameters{$p}:'undef')."'";
        }
    }

    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };

    my @body = [p => a(link => 'All classes', url => $self->{base_uri})];

    if ($parameters{request} eq 'read') {
        $self->read_object($oids, \@body);
        push @body, $footer;
        return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
        
    } elsif ($parameters{request} eq 'update') {
        return http_status($header, 403) if $self->{cookie} eq DEFAULT; # forbidden
        my $obj = SmartSea::Object->new({oid => $oids->first}, $self);
        return http_status($header, 400) unless $obj->{object} && $obj->{source} eq 'Rule'; # bad request

        my $cols = $obj->{object}->values;
        $cols->{value} = $parameters{value};
        $cols->{cookie} = $self->{cookie};
        my $tmp = ['current_timestamp'];
        $cols->{made} = \$tmp;
        eval {
            $obj = $obj->{rs}->update_or_new($cols, {key => 'primary'});
            $obj->insert unless $obj->in_storage;
        };
        say STDERR "error: $@" if $@;
        return http_status($header, 500) if $@;
        return json200($header, {object => $obj->as_hashref_for_json});

    }

    return return http_status($header, 403) if $self->{user} eq 'guest';

    my ($source, $id) = split /:/, $oids->last;
    $id //= $parameters{id};
    my $obj = SmartSea::Object->new({source => $source, id => $id}, $self);
    return http_status($header, 400) unless $obj;

    $url = $self->{uri};
    $url =~ s/\?.*$//;

    # TODO: all actions should be wrapped in begin; commit;

    if ($parameters{request} eq 'add' or $parameters{request} eq 'create') {
        $self->edit_object($obj, $oids, \%parameters, $url, \@body);
        
    } elsif ($parameters{request} eq 'delete') {
        eval {
            $obj->delete($oids->with_index('last'), \%parameters);
        };
        push @body, error_message($@) if $@;
        $self->read_object($oids, \@body);
        
    } elsif ($parameters{request} eq 'save') {
        $parameters{owner} = $self->{user};
        eval {
            $obj->update_or_create($oids->with_index('last'), \%parameters);
        };
        if ($@) {
            push @body, error_message($@);
            return json200({}, {error=>"$@"}) if $self->{json};
            $self->edit_object($obj, $oids, \%parameters, $url, \@body);
        } else {
            return json200({}, $obj->tree) if $self->{json};
            $self->read_object($oids, \@body);
        }
        
    } elsif ($parameters{request} eq 'edit') {
        $self->edit_object($obj, $oids, \%parameters, $url, \@body);
        
    } else {
        return http_status($header, 400);
    }

    push @body, $footer;
    return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
    
}

sub read_object {
    my ($self, $oids, $body) = @_;
    my $obj = SmartSea::Object->new({oid => $oids->first}, $self);
    if ($obj) {
        push @$body, [ul => [li => $obj->item($oids->with_index(0), [], {url => $self->{base_uri}})]];
    } else {
        push @$body, [p => {style => 'color:red'}, $@];
    }
}

sub edit_object {
    my ($self, $obj, $oids, $parameters, $url, $body) = @_;
    my @form = $obj->form($oids->with_index('last'), $parameters);
    if (@form) {
        push @$body, [form => {action => $url, method => 'POST'}, @form];
    } else {
        eval {
            $obj->link($oids->with_index('last'), $parameters);
        };
        push @$body, error_message($@) if $@;
        $self->read_object($oids->with_index(0), $body);
    }
}

sub error_message {
    my $error = shift;
    say STDERR "Error: $@";
    return [p => {style => 'color:red'}, "$error"];
}

1;
