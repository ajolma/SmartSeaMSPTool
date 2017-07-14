package SmartSea::App;
use parent qw/Plack::Component/;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);

sub new {
    my ($class, $self) = @_;
    $self = Plack::Component->new($self);
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    if (!$env->{'psgi.streaming'}) {
        return [ 500, 
                 ["Content-Type" => "text/plain"], 
                 ["Internal Server Error (Server Implementation Mismatch)"] ];
    }
    my %header;
    $header{'Access-Control-Allow-Origin'} //= $env->{HTTP_ORIGIN};
    $header{'Access-Control-Allow-Methods'} //= 'GET,POST';
    $header{'Access-Control-Allow-Headers'} //= 'origin,x-requested-with,content-type';
    $header{'Access-Control-Max-Age'} //= 60*60*24;
    if ($env->{REQUEST_METHOD} eq 'OPTIONS') {
        return [ 200, [%header], [] ];
    }

    $self->{origin} = $env->{HTTP_ORIGIN};
    $self->{header} = { 
        'Access-Control-Allow-Origin' => $self->{origin},
        'Access-Control-Allow-Credentials' => 'true' 
    };
    
    # deny unauthenticated use over https:
    if ($env->{HTTP_X_REAL_PROTOCOL} && $env->{HTTP_X_REAL_PROTOCOL} eq 'https' && !$env->{REMOTE_USER}) {
        return $self->http_status(403);
    }

    my $request = Plack::Request->new($env);
    $self->{cookie} = $request->cookies->{SmartSea} // '';
    
    my $parameters = $request->parameters;

    # two ways to request JSON response
    $self->{accept} = $request->headers->header('Accept') // '';
    $self->{json} = $self->{accept} eq 'application/json';
    $self->{json} = 1 if $parameters->{accept} && $parameters->{accept} eq 'json';

    $self->{debug} = $parameters->{debug} // 0;
    
    return $self->smart($env, $request, $parameters);
}

sub html200 {
    my $self = shift;
    my $html = shift;
    my %header;
    for my $key (keys %{$self->{header}}) {
        $header{$key} = $self->{header}{$key};
    }
    $header{'Content-Type'} //= 'text/html; charset=utf-8';
    $header{'Access-Control-Allow-Origin'} //= '*';
    return [ 200, [%header], [encode utf8 => '<!DOCTYPE html>'.$html] ];
}

sub json200 {
    my $self = shift;
    my $data = shift;
    my $json = JSON->new;
    $json->utf8;
    my %header;
    for my $key (keys %{$self->{header}}) {
        $header{$key} = $self->{header}{$key};
    }
    $header{'Content-Type'} //= 'application/json; charset=utf-8';
    $header{'Access-Control-Allow-Origin'} //= '*';
    return [ 200, [%header], [$json->encode($data)] ];
}

sub http_status {
    my $self = shift;
    my $status = shift;
    my %header;
    for my $key (keys %{$self->{header}}) {
        $header{$key} = $self->{header}{$key};
    }
    $header{'Content-Type'} //= 'text/plain';
    $header{'Access-Control-Allow-Origin'} //= '*';
    return [400, 
            [%header,
             'Content-Length' => 11], 
            ['Bad Request']] if $status == 400;
    return [403, 
            [%header,
             'Content-Length' => 9], 
            ['Forbidden']] if $status == 403;
    return [500, 
            [%header,
             'Content-Length' => 21], 
            ['Internal Server Error']] if $status == 500;
}

1;
