package SmartSea::Core;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;

use constant DEFAULT => 'default'; # not user changed object, used for cookie attribute

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(common_responses html200 json200 http_status parse_integer DEFAULT); 
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub common_responses {
    my $header = shift;
    my $env = shift;
    if (!$env->{'psgi.streaming'}) {
        return [ 500, 
                 ["Content-Type" => "text/plain"], 
                 ["Internal Server Error (Server Implementation Mismatch)"] ];
    }
    my %header;
    for my $key (keys %$header) {
        $header{$key} = $header->{$key};
    }
    $header{'Access-Control-Allow-Origin'} //= '*';
    $header{'Access-Control-Allow-Methods'} //= 'GET,POST';
    $header{'Access-Control-Allow-Headers'} //= 'origin,x-requested-with,content-type';
    $header{'Access-Control-Max-Age'} //= 60*60*24;
    if ($env->{REQUEST_METHOD} eq 'OPTIONS') {
        return [ 200, [%header], [] ];
    }
    return undef;
}

sub html200 {
    my $header = shift;
    my $html = shift;
    my %header;
    for my $key (keys %$header) {
        $header{$key} = $header->{$key};
    }
    $header{'Content-Type'} //= 'text/html; charset=utf-8';
    $header{'Access-Control-Allow-Origin'} //= '*';
    return [ 200, [%header], [encode utf8 => $html] ];
}

sub json200 {
    my $header = shift;
    my $data = shift;
    my $json = JSON->new;
    $json->utf8;
    my %header;
    for my $key (keys %$header) {
        $header{$key} = $header->{$key};
    }
    $header{'Content-Type'} //= 'application/json; charset=utf-8';
    $header{'Access-Control-Allow-Origin'} //= '*';
    return [ 200, [%header], [$json->encode($data)] ];
}

sub http_status {
    my $header = shift;
    my $status = shift;
    my %header;
    for my $key (keys %$header) {
        $header{$key} = $header->{$key};
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

sub parse_integer {
    my $s = shift;
    my $i;
    if ($s =~ /^(\d+)/a) {
        $i = $1;
        $s =~ s/^\d+\D*//a;
    }
    return ($s, $i);
}

1;
