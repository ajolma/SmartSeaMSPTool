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
our @EXPORT_OK = qw(create update common_responses html200 json200 http_status parse_integer DEFAULT warn_unknowns); 
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub create {
    my ($class, $data, $schema, $col) = @_;
    my $_class = 'SmartSea::Schema::Result::'.$class;
    my $attributes = $_class->attributes;
    my %update_data;
    my %unused_data;
    for my $col (keys %$attributes) {
        if ($attributes->{$col}{input} eq 'object') {
            $data = create($attributes->{$col}{class}, $data, $schema, $col);
        }
    }
    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        if (exists $data->{$col}) {
            if ($attributes->{$col}{empty_is_null} && $data->{$col} eq '') {
                $data->{$col} = undef;
            }
        }
    }
    say STDERR "create $class";
    for my $col (keys %$data) {
        if (exists $attributes->{$col}) {
            $update_data{$col} = $data->{$col};
        } else {
            $unused_data{$col} = $data->{$col};
        }
    }
    my $rs = $schema->resultset($class);
    my $obj = $rs->create(\%update_data);
    say STDERR "id for $col is ",$obj->id if defined $col;
    $unused_data{$col} = $obj->id if defined $col;
    return \%unused_data;
}

sub update {
    my ($self, $data) = @_;
    my $attributes = $self->attributes;
    my %update_data;
    my %unused_data;
    for my $col (keys %$attributes) {
        if ($attributes->{$col}{input} eq 'object') {
            my $obj = $self->$col;
            $data = update($obj, $data);
        }
    }
    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        if (exists $data->{$col}) {
            if ($attributes->{$col}{empty_is_null} && $data->{$col} eq '') {
                $data->{$col} = undef;
            }
        }
    }
    say STDERR "update $self";
    for my $col (keys %$data) {
        if (exists $attributes->{$col} && $attributes->{$col}{input} ne 'object') {
            $update_data{$col} = $data->{$col};
        } else {
            $unused_data{$col} = $data->{$col};
        }
    }
    $self->update(\%update_data);
    return \%unused_data;
}

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
    # deny unauthenticated use over https:
    return http_status(\%header, 403) 
        if $env->{HTTP_X_REAL_PROTOCOL} && $env->{HTTP_X_REAL_PROTOCOL} eq 'https' && !$env->{REMOTE_USER};
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

sub warn_unknowns {
    my $arg = shift;
    my %known = map {$_ => 1} @_;
    for my $key (keys %$arg) {
        warn "unknown named argument: $key" unless $known{$key};
    }
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
