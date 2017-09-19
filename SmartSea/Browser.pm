package SmartSea::Browser;
use parent qw/SmartSea::App/;
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

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    $self = SmartSea::App->new($self);
    $self->{sources} = {map {source2class($_) => $_} $self->{schema}->sources};
    ($self->{main_sources}, $self->{simple_sources}, $self->{other_sources}) = $self->{schema}->simple_sources;
    $self->{js} //= 1;
    return bless $self, $class;
}

sub smart {
    my ($self, $env, $request, $parameters) = @_;
    Geo::GDAL->errstr; # clear the error stack
    if ($self->{debug} > 2) {
        for my $key (sort keys %$env) {
            say STDERR "$key => $env->{$key}";
        }
    }
    $self->{user} = $env->{REMOTE_USER} // 'guest';
    $self->{user} = 'ajolma' if $self->{fake_admin};
    $self->{admin} = $self->{user} eq 'ajolma';
    $self->{parameters} = $parameters;
    $self->{root} //= '';
    $self->{path} = $env->{REQUEST_URI};
    $self->{path} =~ s/\?.*$//; # remove the query, it is in parameters

    my $server = $env->{SERVER_NAME};
    $server = 'localhost' if $server eq '127.0.0.1';
    $self->{url} = 'http://'.$server.':'.$env->{SERVER_PORT};
    
    $self->{method} = $env->{REQUEST_METHOD}; # GET, PUT, POST, DELETE
    
    my @objects;
    eval {
        @objects = SmartSea::Object->from_app($self);
    };
    if ($@) {
        $@ =~ s/\s+at .*//;
        return $self->http_status($@) if $self->{json};
        return $self->html200("<html>Error: $@</html>");
    }
    say STDERR "remote user is $self->{user}" if $self->{debug};
    say STDERR "cookie: $self->{cookie}" if $self->{debug};
    say STDERR "full path: $self->{path}" if $self->{debug};
    say STDERR "root: $self->{root}" if $self->{debug};
    say STDERR "objects: ",$objects[0]->str_all if @objects && $self->{debug};
    my $response;
    eval {
        $response = $self->object_editor(\@objects);
    };
    return $self->html200(SmartSea::HTML->new(html => [body => error_message($@)])->html) if $@;
    return $response;
}

sub object_editor {
    my ($self, $objects) = @_;
    
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
        if ($self->{debug} > 1) {
            for my $value ($self->{parameters}->get_all($key)) {
                say STDERR "$key => $value";
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
        my $last = $objects->[$#$objects];
        my $class = $last->{class}; # what to delete
        $self->{parameters}->remove($class); # from a select accompanying create button
        my ($id) = $self->{parameters}{delete} =~ /(\d+)/;
        say STDERR "delete = $last->{source}:$id" if $self->{debug};
        $last = SmartSea::Object->new({source => $last->{source}, id => $id, app => $last->{app}});
        $objects->[$#$objects] = $last;
        delete $self->{parameters}{delete};
        $request = 'delete';
    } else {
        $request = 'read';
    }
    $self->{request} = $request;
    say STDERR "request = $request" if $self->{debug};

    unless (@$objects) {
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
        return $self->json200(\@classes) if $self->{json};
        push @body, $footer;
        return $self->html200(SmartSea::HTML->new(html => [body => \@body])->html);
    }

    my @body = [p => a(link => 'All classes', url => $self->{root})];
    #push @body, [div => {class=>"se-pre-con"}, ''];

    my $first = $objects->[0];
    my $last = $objects->[$#$objects];
    if ($request eq 'read') {
        return $self->json200($last->read) if $self->{json};
        my $part = [ul => [li => $first->item([], {url => $self->{root}})]];
        push @body, $part;
        push @body, $footer;
        return $self->html200(SmartSea::HTML->new(html => [body => @body])->html);
        
    } elsif ($request eq 'modify') {
        return $self->http_status(403) unless $self->{cookie}; # not for guests or cookie-afraid
        return $self->http_status(400) unless $last->{row} && $last->{source} eq 'Rule'; # bad request

        my $cols = $last->{row}->values;
        $cols->{value} = $self->{parameters}{value};
        $cols->{cookie} = $self->{cookie};
        my $tmp = ['current_timestamp'];
        $cols->{made} = \$tmp;
        my $object;
        eval {
            $object = $last->{rs}->update_or_new($cols, {key => 'primary'});
            $object->insert unless $object->in_storage;
        };
        say STDERR "error: $@" if $@;
        return $self->http_status(500) if $@;
        return $self->json200({object => $object->read});

    }

    return return $self->http_status(403) if $self->{user} eq 'guest';

    # TODO: all actions should be wrapped in begin; commit;

    if ($request eq 'compute') {
        # from HTML form, do computation and go back to form with the data
        $last->compute_cols();
        push @body, [form => {action => $self->{path}, method => 'POST'}, $last->form];
        
    } elsif ($request eq 'create') {
        my $class = $last->{class}; # what to create
        my @id = $self->{parameters}->get_all($class);
        my @errors;
        if (@id) {
            for my $id (@id) {
                my $o = SmartSea::Object->new({source => $last->{source}, id => $id, app => $last->{app}});
                eval {
                    push @errors, $o->create();
                };
            }
        } else {
            eval {
                push @errors, $last->create();
            };
        }
        my $part;
        if ($@) {
            push @body, error_message($@) if $@;
            return $self->json200({error => $@}) if $self->{json};
        } elsif (@errors) {
            return $self->json200({error => \@errors}) if $self->{json};
            $part = [form => {action => $self->{path}, method => 'POST'}, $last->form({input_is_fixed=>1})];
        } else {
            return $self->json200($first->read) if $self->{json};
        }
        $part = [ul => [li => $first->item([], {url => $self->{root}})]] unless $part;
        push @body, $part;
        
    } elsif ($request eq 'delete') {
        my $class = $last->{class}; # what to delete
        my @id = $self->{parameters}->get_all($class);
        if (@id) {
            say STDERR "delete $class:@id" if $self->{debug};
            for my $id (@id) {
                my $o = SmartSea::Object->new({source => $last->{source}, id => $id, app => $last->{app}});
                eval {
                    $o->delete();
                };
            }
        } else {
            eval {
                $last->delete();
            };
        }
        if ($self->{json}) {
            return $self->json200({error => "$@"}) if $@;
            return $self->json200({result => 'ok'});
        }
        push @body, error_message($@) if $@;
        my $part = [ul => [li => $first->item([], {url => $self->{root}})]];
        push @body, $part;

    } elsif ($request eq 'update') {
        eval {
            my $what = $last;
            my @errors;
            if ($what->{row}) {
                @errors = $what->update;
            } else {
                @errors = $what->create;
            }
            croak join(', ', @errors) if @errors;
        };
        if ($@) {
            push @body, error_message($@);
            return $self->json200({error=>"$@"}) if $self->{json};
            push @body, [form => {action => $self->{path}, method => 'POST'}, $last->form];
        } else {
            return $self->json200($last->read) if $self->{json};
            my $part = [ul => [li => $first->item([], {url => $self->{root}})]];
            push @body, $part;
        }

    } elsif ($request eq 'save') {
        eval {
            my $what = $last;
            my @errors;
            if ($what->{row}) {
                @errors = $what->update;
            } else {
                @errors = $what->create;
            }
            croak join(', ', @errors) if @errors;
        };
        if ($@) {
            return $self->json200({error=>"$@"}) if $self->{json};
            push @body, error_message($@);
            push @body, [form => {action => $self->{path}, method => 'POST'}, $last->form];
        } else {
            return $self->json200($last->read) if $self->{json};
            my $part = [ul => [li => $first->item([], {url => $self->{root}})]];
            push @body, $part;
        }
        
    } elsif ($request eq 'edit') {
        push @body, [form => {action => $self->{path}, method => 'POST'}, $last->form];
        
    } else {
        return $self->http_status(400);
    }

    push @body, $footer;
    return $self->html200(SmartSea::HTML->new(html => [head(),[body => @body]])->html);
    
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
