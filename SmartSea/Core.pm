package SmartSea::Core;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT    = qw(common_responses html200 json200 return_400 return_403 a);

sub common_responses {
    my $env = shift;
    if (!$env->{'psgi.streaming'}) {
        return [ 500, 
                 ["Content-Type" => "text/plain"], 
                 ["Internal Server Error (Server Implementation Mismatch)"] ];
    }
    if ($env->{REQUEST_METHOD} eq 'OPTIONS') {
        return [ 200, 
                 [
                  "Access-Control-Allow-Origin" => "*",
                  "Access-Control-Allow-Methods" => "GET,POST",
                  "Access-Control-Allow-Headers" => "origin,x-requested-with,content-type",
                  "Access-Control-Max-Age" => 60*60*24
                 ], 
                 [] ];
    }
    return undef;
}

sub html200 {
    my $html = shift;
    return [ 200, 
             [ 'Content-Type' => 'text/html; charset=utf-8',
               'Access-Control-Allow-Origin' => '*' ], 
             [encode utf8 => $html]
        ];
}

sub json200 {
    my $data = shift;
    my $json = JSON->new;
    $json->utf8;
    return [
        200, 
        [ 'Content-Type' => 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin' => '*' ],
        [$json->encode($data)]];
}

sub return_400 {
    my $self = shift;
    return [400, ['Content-Type' => 'text/plain', 'Content-Length' => 11], ['Bad Request']];
}

sub return_403 {
    my $self = shift;
    return [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']];
}

sub a {
    my ($link, $url) = @_;
    return [a => $link, {href=>$url}];
}
