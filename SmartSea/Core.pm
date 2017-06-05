package SmartSea::Core;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;

use constant DEFAULT => 'default'; # not user changed object, used for cookie column

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    common_responses html200 json200 http_status DEFAULT warn_unknowns
    source2table table2source singular plural
);
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
    $header{'Access-Control-Allow-Origin'} //= $env->{HTTP_ORIGIN};
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
    return [ 200, [%header], [encode utf8 => '<!DOCTYPE html>'.$html] ];
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

sub source2table {
    my $source = shift;
    $source =~ s/([a-z])([A-Z])/$1_$2/g;
    return lc($source);
}

sub table2source {
    my $table = shift;
    $table = singular($table);
    $table =~ s/^(\w)/uc($1)/e;
    $table =~ s/_(\w)/uc($1)/ge;
    $table =~ s/(\d\w)/uc($1)/e;
    return $table;
}

sub singular {
    my ($w) = @_;
    if ($w =~ /ies$/) {
        $w =~ s/ies$/y/;
    } elsif ($w =~ /sses$/) {
        $w =~ s/sses$/ss/;
    } elsif ($w =~ /ss$/) {
    } else {
        $w =~ s/s$//;
    }
    return $w;
}

sub plural {
    my ($w) = @_;
    $w =~ s/([a-z])([A-Z])/"$1 ".lc($2)/ge;
    if ($w =~ /y$/) {
        $w =~ s/y$/ies/;
    } elsif ($w =~ /ss$/) {
        $w =~ s/ss$/sses/;
    } elsif ($w =~ /s$/) {
    } else {
        $w .= 's';
    }
    return $w;
}

{
    package SmartSea::OIDS;
    # a path of oids
    # oid = table:id
    sub new {
        my ($class, $path, $root) = @_;
        my $self = {};
        my @oids;
        if (defined $path) {
            $path =~ s/^$root// if defined $root;
            @oids = split /\//, $path;
            shift @oids; # the first ''
        }
        $self->{oids} = \@oids;
        $self->{n} = $#oids+1;
        $self->{index} = $self->{n} > 0 ? 0 : -1;
        bless $self, $class;
    }
    sub with_index {
        my ($self, $index) = @_;
        if ($index eq 'last') {
            $self->{index} = $self->{n}-1;
        } elsif ($index eq 'next') {
            $self->{index} = $self->{index}+1;
        } else {
            $self->{index} = $index;
        }
        $self->{index} = -1 unless $self->{index} < $self->{n};
        return $self;
    }
    sub count {
        my $self = shift;
        return $self->{n};
    }
    sub at {
        my ($self, $i) = @_;
        $i //= $self->{index};
        return undef if $i < 0 || $i >= $self->{n};
        return $self->{oids}[$i];
    }
    sub is_empty {
        my $self = shift;
        return $self->{n} == 0;
    }
    sub first {
        my $self = shift;
        return undef if $self->{n} == 0;
        return $self->{oids}[0];
    }
    sub last {
        my $self = shift;
        return undef if $self->{n} == 0;
        return $self->{oids}[$self->{n}-1];
    }
    sub set_last_id {
        my ($self, $id) = @_;
        return undef if $self->{n} == 0;
        $self->{oids}[$self->{n}-1] .= ':'.$id;
    }
    sub has_next {
        my $self = shift;
        return $self->{index}+1 < $self->{n};
    }
    sub next {
        my $self = shift;
        return $self->{oids}[$self->{index}+1];
    }
    sub has_prev {
        my $self = shift;
        return $self->{index}-1 >= 0;
    }
    sub prev {
        my $self = shift;
        return $self->{oids}[$self->{index}-1];
    }
}

1;
