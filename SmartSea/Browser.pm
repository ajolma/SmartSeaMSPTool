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
    $self->{root} //= '';
    $self->{path} = $env->{REQUEST_URI};
    $self->{path} =~ s/\?.*$//; # remove the query, it is in parameters
    my $oids = SmartSea::OIDS->new($self->{path}, $self->{root});
    $self->{method} = $env->{REQUEST_METHOD}; # GET, PUT, POST, DELETE
    $self->{origin} = $env->{HTTP_ORIGIN};
    say STDERR "remote user is $self->{user}" if $self->{debug};
    say STDERR "cookie: $self->{cookie}" if $self->{debug};
    say STDERR "full path: $self->{path}" if $self->{debug};
    say STDERR "root: $self->{root}" if $self->{debug};
    say STDERR "oids: @{$oids->{oids}} ($oids->{n})" if $self->{debug};
    return $self->object_editor($oids);
}

sub object_editor {
    my ($self, $oids) = @_;
    
    my $schemas = $self->{table_postfix} // '';
    $schemas =~ s/^_//;
    my $footer = [p => {style => 'font-size:0.8em'}, "Schema set = $schemas. User = $self->{user}."];

    if ($oids->is_empty) {
        my @body = a(link => 'Up', url => $self->{home});
        my @li;
        for my $source (sort $self->{schema}->sources) {
            my $table = source2table($source);
            push @li, [li => a(link => SmartSea::Object::plural($source), url => $self->{root}.'/'.$table)]
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

    my %parameters;
    
    # $self->{parameters} is a multivalue hash
    # we may have both object => command and object => id
    for my $key (sort keys %{$self->{parameters}}) {
        for my $value ($self->{parameters}->get_all($key)) {
            say STDERR "$key => $value" if $self->{debug} > 1;
            if ($key eq 'submit' && $value =~ /^Compute/) {
                $parameters{request} = 'edit';
                $parameters{compute} = $value;
                last;
            }
            $value = decode utf8 => $value;
            my $done = 0;
            for my $request (qw/create add read edit update modify save delete remove/) {
                if (lc($value) eq $request || lc($key) eq $request) {
                    $request = 'delete' if $request eq 'remove';
                    $parameters{request} = $request;
                    if ($request eq 'delete') {
                        $parameters{id} //= $key;
                    } else {
                        $parameters{$request} = $key;
                    }
                    $done = 1;
                    last;
                }
            }
            next if $done;
            $done = 0;
            if ($key eq 'accept' && $value eq 'json') {
                $self->{json} = 1;
                $done = 1;
            }
            next if $done;
            if ($value eq 'NULL') {
                $parameters{$key} = undef;
            } else {
                $parameters{$key} = $value;
            }
        }
    }
    $parameters{request} //= 'read';
    say STDERR "request = $parameters{request}" if $self->{debug} > 1;

    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };

    my @body = [p => a(link => 'All classes', url => $self->{root})];

    if ($parameters{request} eq 'read') {
        my $part = $self->read_object($oids);
        return json200({}, $part) if $self->{json};
        push @body, $part;
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
        return json200($header, {object => $obj->tree});

    }

    return return http_status($header, 403) if $self->{user} eq 'guest';

    my ($source, $id) = split /:/, $oids->last;
    $id //= $parameters{id};
    my $obj = SmartSea::Object->new({source => $source, id => $id}, $self);
    return http_status($header, 400) unless $obj;

    # TODO: all actions should be wrapped in begin; commit;

    if ($parameters{request} eq 'add' or $parameters{request} eq 'create') {
        $self->edit_object($obj, $oids, \%parameters, \@body);
        
    } elsif ($parameters{request} eq 'delete') {
        eval {
            $obj->delete($oids->with_index('last'), \%parameters);
        };
        if ($self->{json}) {
            return json200({}, {error => "$@"}) if $@;
            return json200({}, {result => 'ok'});
        }
        push @body, error_message($@) if $@;
        my $part = $self->read_object($oids);
        push @body, $part;
        
    } elsif ($parameters{request} eq 'save') {
        $parameters{owner} = $self->{user};
        eval {
            $obj->update_or_create($oids->with_index('last'), \%parameters);
        };
        if ($@) {
            push @body, error_message($@);
            return json200({}, {error=>"$@"}) if $self->{json};
            $self->edit_object($obj, $oids, \%parameters, \@body);
        } else {
            return json200({}, $obj->tree) if $self->{json};
            my $part = $self->read_object($oids);
            push @body, $part;
        }
        
    } elsif ($parameters{request} eq 'edit') {
        $self->edit_object($obj, $oids, \%parameters, \@body);
        
    } else {
        return http_status($header, 400);
    }

    push @body, $footer;
    return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
    
}

sub read_object {
    my ($self, $oids) = @_;
    my $obj = SmartSea::Object->new({oid => $oids->first}, $self);
    if ($obj) {
        return $obj->tree if $self->{json};
        return [ul => [li => $obj->item($oids->with_index(0), [], {url => $self->{root}})]];
    } else {
        return {error=>"$@"} if $self->{json};
        return [p => {style => 'color:red'}, $@];
    }
}

sub edit_object {
    my ($self, $obj, $oids, $parameters, $body) = @_;
    my @form = $obj->form($oids->with_index('last'), $parameters);
    if (@form) {
        push @$body, [form => {action => $self->{path}, method => 'POST'}, @form];
    } else {
        eval {
            $obj->link($oids->with_index('last'), $parameters);
        };
        push @$body, error_message($@) if $@;
        my $part = $self->read_object($oids->with_index(0));
        return json200({}, $part) if $self->{json};
        push @$body, $part;
        
    }
}

sub error_message {
    my $error = shift;
    say STDERR "Error: $@";
    return [p => {style => 'color:red'}, "$error"];
}

1;
