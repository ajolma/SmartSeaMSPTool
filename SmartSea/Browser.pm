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
    $self->{sources} = {map {source2class($_) => $_} $self->{schema}->sources};
    ($self->{main_sources}, $self->{simple_sources}) = $self->{schema}->simple_sources;
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

    my $server = $env->{SERVER_NAME};
    $server = 'localhost' if $server eq '127.0.0.1';
    $self->{url} = 'http://'.$server.':'.$env->{SERVER_PORT};
    
    $self->{method} = $env->{REQUEST_METHOD}; # GET, PUT, POST, DELETE
    $self->{origin} = $env->{HTTP_ORIGIN};
    my $object;
    eval {
        $object = SmartSea::Object->from_app($self);
    };
    if ($@) {
        $@ =~ s/ at SmartSea.*//;
        return json200({}, {error=>"$@"}) if $self->{json};
        return html200({}, "<html>Error: $@</html>");
    }
    say STDERR "remote user is $self->{user}" if $self->{debug};
    say STDERR "cookie: $self->{cookie}" if $self->{debug};
    say STDERR "full path: $self->{path}" if $self->{debug};
    say STDERR "root: $self->{root}" if $self->{debug};
    say STDERR "objects: ",$object->str_all if $object && $self->{debug};
    return $self->object_editor($object);
}

sub object_editor {
    my ($self, $object) = @_;
    
    my $schemas = $self->{table_postfix} // '';
    $schemas =~ s/^_//;
    my $footer = [p => {style => 'font-size:0.8em'}, "Schema set = $schemas. User = $self->{user}."];

    # CRUD: 
    # create is one-step only for links, otherwise edit (without id) + save, 
    # read is default, 
    # update may create, and is known as edit + save
    # modify is allowed only on rules and it is a (copy+)update identified with cookie
    # delete does not do deep

    my %parameters;
    
    # $self->{parameters} is a multivalue hash
    # we may have both object => command and object => id
    my $request;
    for my $key (sort keys %{$self->{parameters}}) {
        my @values = $self->{parameters}->get_all($key);
        $self->{parameters}->remove($key);
        for (@values) {
            $_ = decode utf8 => $_;
        }
        $self->{parameters}->add($key, @values);
        for my $value ($self->{parameters}->get_all($key)) {
            $self->{debug} = $value if $key eq 'debug';
            say STDERR "$key => $value" if $self->{debug} > 1;
            if ($key eq 'submit' && $value =~ /^Compute/) {
                $request = 'edit';
                $self->{parameters}->add(compute => $value);
                last;
            }
            my $done = 0;
            for (qw/create add read edit modify update save delete remove/) {
                # remove means "delete link or link object"
                my $cmd = $_;
                if (lc($value) eq $cmd && ($key eq 'request' || $key eq 'submit' || $key =~ /^\d+$/)) {
                    $request = $cmd;
                    $request = 'delete' if $request eq 'remove';
                    $request = 'save' if $request eq 'update';
                    $request = 'add' if $request eq 'create';
                    # set target object id from button where, name is id, command is value
                    #$object->set_last_id($key) if $key =~ /^\d+$/; # the key may also be the id
                    $self->{parameters}->add($request => $key) if $key =~ /^\d+$/; # the key may also be the id
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
                $self->{parameters}->remove($key);
            }
        }
    }
    # set target object id from parameter
    #unless ($object->is_empty) {
        #my ($source, $oid) = $object->at('last');
        #my $id = $self->{parameters}{$source};
        #if ($source && $id && !$oid) {
        #    $object->set_last_id($id);
        #}
    #}
    $request //= 'read';
    say STDERR "request = $request" if $self->{debug} > 1;
    #return http_status({}, 403);

    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };

    unless ($object) {
        my @classes;
        my @body = a(link => 'Up', url => $self->{home});
        {
            my @li;
            for my $source (sort keys %{$self->{main_sources}}) {
                my $class = source2class($source);
                push @li, [li => a(link => SmartSea::Object::plural($source), url => $self->{root}.'/'.$class)];
                push @classes, {class => $class, href => $self->{url}.$self->{root}.'/'.$class.'?accept=json'};
            }
            push @body, [p => [1 => "Main classes"],[ul=>\@li]];
        }
        {
            my @li;
            for my $source (sort keys %{$self->{simple_sources}}) {
                my $class = source2class($source);
                push @li, [li => a(link => SmartSea::Object::plural($source), url => $self->{root}.'/'.$class)];
                push @classes, {class => $class, href => $self->{url}.$self->{root}.'/'.$class.'?accept=json'};
            }
            push @body, [p => [1 => "Simple classes"],[ul=>\@li]];
        }
        return json200({}, \@classes) if $self->{json};
        push @body, $footer;
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    }

    my @body = [p => a(link => 'All classes', url => $self->{root})];

    if ($request eq 'read') {
        return json200({}, $object->read) if $self->{json};
        my $part = $self->read_object($object);
        push @body, $part;
        push @body, $footer;
        return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
        
    } elsif ($request eq 'modify') {
        return http_status($header, 403) if $self->{cookie} eq DEFAULT; # forbidden
        return http_status($header, 400) unless $object->{object} && $object->{source} eq 'Rule'; # bad request

        my $cols = $object->{object}->values;
        $cols->{value} = $self->{parameters}{value};
        $cols->{cookie} = $self->{cookie};
        my $tmp = ['current_timestamp'];
        $cols->{made} = \$tmp;
        eval {
            $object = $object->{rs}->update_or_new($cols, {key => 'primary'});
            $object->insert unless $object->in_storage;
        };
        say STDERR "error: $@" if $@;
        return http_status($header, 500) if $@;
        return json200($header, {object => $object->tree});

    }

    return return http_status($header, 403) if $self->{user} eq 'guest';

    return http_status($header, 400) unless $object;

    # TODO: all actions should be wrapped in begin; commit;

    if ($request eq 'add') {
        my @errors;
        eval {
            @errors = $object->last->create();
        };
        if ($@) {
            push @body, error_message($@) if $@;
            return json200({}, {error => $@}) if $self->{json};
            my $part = $self->read_object($object);
            push @body, $part;
        } elsif (@errors) {
            return json200({}, {error => \@errors}) if $self->{json};
            $self->edit_object($object, \@body);
        } else {
            return json200({}, $object->first->read) if $self->{json};
            my $part = $self->read_object($object->prev);
            push @body, $part;
        }

    } elsif ($request eq 'delete') {
        eval {
            $object->last->delete;
        };
        if ($self->{json}) {
            return json200({}, {error => "$@"}) if $@;
            return json200({}, {result => 'ok'});
        }
        push @body, error_message($@) if $@;
        my $part = $self->read_object($object->prev);
        push @body, $part;

    } elsif ($request eq 'save') {
        eval {
            $object->last->update_or_create;
        };
        if ($@) {
            push @body, error_message($@);
            return json200({}, {error=>"$@"}) if $self->{json};
            $self->edit_object($object->last, \@body);
        } else {
            return json200({}, $object->first->read) if $self->{json};
            my $part = $self->read_object($object->prev);
            push @body, $part;
        }
        
    } elsif ($request eq 'edit') {
        $self->edit_object($object->last, \@body);
        
    } else {
        return http_status($header, 400);
    }

    push @body, $footer;
    return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
    
}

sub read_object {
    my ($self, $object) = @_;
    if ($object) {
        return [ul => [li => $object->first->item([], {url => $self->{root}})]];
    } else {
        return [p => {style => 'color:red'}, $@];
    }
}

sub edit_object {
    my ($self, $object, $body) = @_;
    my @form = $object->last->form();
    push @$body, [form => {action => $self->{path}, method => 'POST'}, @form];
}

sub error_message {
    my $error = shift;
    say STDERR "Error: $@";
    return [p => {style => 'color:red'}, "$error"];
}

1;
