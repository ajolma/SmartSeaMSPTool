package SmartSea::Core;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(warn_unknowns source2class table2source singular plural);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub warn_unknowns {
    my $arg = shift;
    my %known = map {$_ => 1} @_;
    for my $key (keys %$arg) {
        warn "unknown named argument: $key" unless $known{$key};
    }
}

sub source2class {
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

1;
