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
    ($self->{main_sources}, $self->{simple_sources}, $self->{other_sources}) = $self->{schema}->simple_sources;
    $self->{js} //= 1;
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
    my $response;
    eval {
        $response = $self->object_editor($object);
    };
    return html200({}, SmartSea::HTML->new(html => [body => error_message($@)])->html) if $@;
    return $response;
}

sub object_editor {
    my ($self, $object) = @_;
    
    my $schemas = $self->{table_postfix} // '';
    $schemas =~ s/^_//;
    my $footer = [p => {style => 'font-size:0.8em'}, "Schema set = $schemas. User = $self->{user}."];

    # $self->{parameters} is a multivalue hash
    for my $key (sort keys %{$self->{parameters}}) {
        my @values = $self->{parameters}->get_all($key);
        $self->{parameters}->remove($key);
        for (@values) {
            $_ = decode utf8 => $_;
        }
        $self->{parameters}->add($key, @values);
        for my $value ($self->{parameters}->get_all($key)) {
            if ($key eq 'debug') {
                $self->{debug} = $value;
            } elsif ($key eq 'accept' && $value eq 'json') {
                $self->{json} = 1;
            } else {
                say STDERR "$key => $value" if $self->{debug};
            }
        }
    }
    my $request;
    if ($self->{parameters}{request}) {
        $request = $self->{parameters}{request};
        delete $self->{parameters}{request};
    } elsif ($self->{parameters}{delete}) {
        # from HTML form
        # attempt to delete and show the changed object
        # delete does not do deep
        my $class = $object->last->{class}; # what to delete
        $self->{parameters}->remove($class); # from a select accompanying create button
        $object->last->id($self->{parameters}{delete} =~ /(\d+)/);
        delete $self->{parameters}{delete};
        $request = 'delete';
    } else {
        $request = 'read';
    }
    $self->{request} = $request;
    say STDERR "request = $request" if $self->{debug};

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
                push @li, [li => a(link => plural($source), url => $self->{root}.'/'.$class)];
                push @classes, {class => $class, href => $self->{url}.$self->{root}.'/'.$class.'?accept=json'};
            }
            push @body, [p => [1 => "Main classes"],[ul=>\@li]];
        }
        {
            my @li;
            for my $source (sort keys %{$self->{simple_sources}}) {
                my $class = source2class($source);
                push @li, [li => a(link => plural($source), url => $self->{root}.'/'.$class)];
                push @classes, {class => $class, href => $self->{url}.$self->{root}.'/'.$class.'?accept=json'};
            }
            push @body, [p => [1 => "Simple classes"],[ul=>\@li]];
        }
        {
            my @li;
            for my $source (sort keys %{$self->{other_sources}}) {
                my $class = source2class($source);
                push @li, [li => a(link => plural($source), url => $self->{root}.'/'.$class)];
                push @classes, {class => $class, href => $self->{url}.$self->{root}.'/'.$class.'?accept=json'};
            }
            push @body, [p => [1 => "Other classes"],[ul=>\@li]];
        }
        return json200({}, \@classes) if $self->{json};
        push @body, $footer;
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    }

    my @body = [p => a(link => 'All classes', url => $self->{root})];
    #push @body, [div => {class=>"se-pre-con"}, ''];

    if ($request eq 'read') {
        return json200({}, $object->read) if $self->{json};
        my $part = [ul => [li => $object->first->item([], {url => $self->{root}})]];
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

    if ($request eq 'compute') {
        # from HTML form, do computation and go back to form with the data
        $object->last->compute_cols();
        push @body, [form => {action => $self->{path}, method => 'POST'}, $object->last->form];
        
    } elsif ($request eq 'create') {
        my $class = $object->last->{class}; # what to create
        my @id = $self->{parameters}->get_all($class);
        my @errors;
        if (@id) {
            for my $id (@id) {
                $object->last->id($id);
                eval {
                    push @errors, $object->last->create();
                };
            }
        } else {
            eval {
                push @errors, $object->last->create();
            };
        }
        my $part;
        if ($@) {
            push @body, error_message($@) if $@;
            return json200({}, {error => $@}) if $self->{json};
        } elsif (@errors) {
            return json200({}, {error => \@errors}) if $self->{json};
            $part = [form => {action => $self->{path}, method => 'POST'}, $object->last->form];
        } else {
            return json200({}, $object->first->read) if $self->{json};
        }
        $part = [ul => [li => $object->first->item([], {url => $self->{root}})]] unless $part;
        push @body, $part;
        
    } elsif ($request eq 'delete') {
        my $class = $object->last->{class}; # what to delete
        my @id = $self->{parameters}->get_all($class);
        if (@id) {
            for my $id (@id) {
                $object->last->id($id);
                eval {
                    $object->last->delete();
                };
            }
        } else {
            eval {
                $object->last->delete();
            };
        }
        if ($self->{json}) {
            return json200({}, {error => "$@"}) if $@;
            return json200({}, {result => 'ok'});
        }
        push @body, error_message($@) if $@;
        my $part = [ul => [li => $object->first->item([], {url => $self->{root}})]];
        push @body, $part;

    } elsif ($request eq 'update' || $request eq 'save') {
        eval {
            $object->last->update_or_create;
        };
        if ($@) {
            push @body, error_message($@);
            return json200({}, {error=>"$@"}) if $self->{json};
            push @body, [form => {action => $self->{path}, method => 'POST'}, $object->last->form];
        } else {
            return json200({}, $object->last->read) if $self->{json};
            my $part = [ul => [li => $object->first->item([], {url => $self->{root}})]];
            push @body, $part;
        }
        
    } elsif ($request eq 'edit') {
        push @body, [form => {action => $self->{path}, method => 'POST'}, $object->last->form];
        
    } else {
        return http_status($header, 400);
    }

    push @body, $footer;
    return html200({}, SmartSea::HTML->new(html => [head(),[body => @body]])->html);
    
}

sub error_message {
    my $error = shift;
    say STDERR "Error: $error";
    $error =~ s/ at .*//;
    return [p => {style => 'color:red'}, "$error"];
}

sub head {
    return [head => ''];
    my $css = <<'END_CSS';
.no-js #loader { display: none;  }
.js #loader { display: block; position: absolute; left: 100px; top: 0; }
.se-pre-con {
	position: fixed;
	left: 0px;
	top: 0px;
	width: 100%;
	height: 100%;
	z-index: 9999;
	background: url(images/loader-64x/Preloader_2.gif) center no-repeat #fff;
}
END_CSS
    my $js = <<'END_JS';
	$(window).load(function() {
		// Animate loader off screen
		$(".se-pre-con").fadeOut("slow");;
	});
END_JS
return [head => [
            [script => {src=>"http://ajax.googleapis.com/ajax/libs/jquery/1.5.2/jquery.min.js"}, ''],
            [script => {src=>"http://cdnjs.cloudflare.com/ajax/libs/modernizr/2.8.2/modernizr.js"}, ''],
            [script => [1 => $js]], 
            [style => {type=>"text/css"},[1 => $css]]
        ]];
}

1;
