package SmartSea::Schema::Result::Impact;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id                  => {},
    pressure            => { is_foreign_key => 1, source => 'Pressure', parent => 1, not_null => 1 },
    ecosystem_component => { is_foreign_key => 1, source => 'EcosystemComponent', not_null => 1 },
    strength            => { is_foreign_key => 1, source => 'ImpactStrength' },
    belief              => { is_foreign_key => 1, source => 'Belief' },
    );

__PACKAGE__->table('impacts');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(pressure => 'SmartSea::Schema::Result::Pressure');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');
__PACKAGE__->belongs_to(strength => 'SmartSea::Schema::Result::ImpactStrength');
__PACKAGE__->belongs_to(belief => 'SmartSea::Schema::Result::Belief');

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my ($self) = @_;
    return $self->pressure->name.' -> '.$self->ecosystem_component->name;
}

# a proposal for impact computations
# strength = 0..4, 0 denotes no impact, 4 denotes most severe impact
# belief = 1..3,1 denotes very uncertain, 3 denotes certain

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

sub pdf {
    my ($self) = @_;
    my $s = defined $self->strength ? $self->strength->value : 2;
    my $b = defined $self->belief ? $self->belief->value : 2;
    return $pdf{$s}{$b};
}

sub pdf_sum {
    my ($self, $pdf_b) = @_;
    my $pdf_a = $self->pdf;
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

sub expected_value {
    my ($self, $pdf) = @_;
    $pdf //= $self->pdf;
    my $e = 0;
    for my $i (0..4) {
        $e += $pdf->[$i]*$i;
    }
    return $e;
}

1;
