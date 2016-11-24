package SmartSea::Impact;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(%range %strength %belief %pdf impact_pdf impact_sum impact_expected_value);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

# TODO: make this a class

# a proposal for impact computations for the Marisplan strength / belief data
# strength = 0..4, 0 denotes no impact, 4 denotes most severe impact
# belief = 1..3,1 denotes very uncertain, 3 denotes certain

our %range = (1 => 'local', 2 => '< 500 m', 3 => '< 1 km', 4 => '< 10 km', 5 => '< 20 km', 6 => '> 20 km');
our %strength = (0 => 'nil', 1 => 'very weak', 2 => 'weak', 3 => 'strong', 4 => 'very strong');
our %belief = (1 => 'but this is very uncertain', 2 => 'but this is uncertain', 3 => 'and this is certain');

# strength -> belief -> pdf
# the pdf's are based on nothing, only that the expected value is correct
our %pdf = (
    4 => {
        1 => [0, 0.03, 0.08, 0.22, 0.67],
        2 => [0, 0,    0.05, 0.15, 0.8],
        3 => [0, 0,    0,    0.05, 0.95]
    },
    3 => {
        1 => [0, 0.08, 0.16, 0.6,  0.16],
        2 => [0, 0,    0.1,  0.8,  0.1],
        3 => [0, 0,    0.025,0.95, 0.025]
    },
    2 => {
        1 => [0.05, 0.2,  0.5,  0.2,  0.05],
        2 => [0.02, 0.15, 0.65, 0.15, 0.03],
        3 => [0,    0.1,  0.8,  0.1,  0],
    },
    1 => {
        1 => [0.16,  0.6,  0.16,  0.08, 0],
        2 => [0.1,   0.8,  0.1,   0,    0],
        3 => [0.025, 0.95, 0.025, 0,    0]
    },
    0 => {
        1 => [0.67, 0.22, 0.08, 0.03, 0],
        2 => [0.8,  0.15, 0.05, 0,    0],
        3 => [0.95, 0.05, 0,    0,    0]
    }
);

sub impact_pdf {
    my ($strength, $belief) = @_;
    return $pdf{$strength}{$belief};
}

sub impact_sum {
    my $pdf_a;
    my $pdf_b;
    if (@_ == 4) {
        my ($a_strength, $a_belief, $b_strength, $b_belief) = @_;
        $pdf_a = $pdf{$a_strength}{$a_belief};
        $pdf_b = $pdf{$b_strength}{$b_belief};
    } elsif (@_ == 2) {
        ($pdf_a, $pdf_b) = @_;
    } elsif (ref $_[0]) {
        my ($b_strength, $b_belief);
        ($pdf_a, $b_strength, $b_belief) = @_;
        $pdf_b = $pdf{$b_strength}{$b_belief};
    } else {
        my ($a_strength, $a_belief);
        ($a_strength, $a_belief, $pdf_b) = @_;
        $pdf_a = $pdf{$a_strength}{$a_belief};
    }
    my @pdf = (0,0,0,0,0);
    # all combinations
    for my $s_a (0..4) {
        for my $s_b (0..4) {
            my $p = $pdf_a->[$s_a] * $pdf_b->[$s_b];
            # sum is max
            my $s = $s_a > $s_b ? $s_a : $s_b;
            $pdf[$s] += $p;
        }
    }
    return \@pdf;
}

sub impact_expected_value {
    my $pdf;
    if (@_ == 2) {
        my ($strength, $belief) = @_;
        $pdf = $pdf{$strength}{$belief};
    } else {
        $pdf = shift;
    }
    my $e = 0;
    for my $i (0..4) {
        $e += $pdf->[$i]*$i;
    }
    return $e;
}

1;
