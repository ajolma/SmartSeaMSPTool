package SmartSea::Schema::ResultSet::Dataset;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub list {
    my $self = shift;
    $self->search({ -and => [is_a_part_of => undef, is_derived_from => undef] }, {order_by => {-asc => 'name'}});
}

# a layers for a "plan" from all real datasets
sub layers {
    my ($self) = @_;
    my @datasets;
    for my $dataset ($self->search(undef, {order_by => {-asc => 'name'}})->all) {
        my $usable = $dataset->usable_in_rule;
        #say STDERR "dataset ".$dataset->id." ".($usable ? 'usable' : 'not usable');
        next unless $usable;
        push @datasets, $dataset->read;
    }
    return @datasets if wantarray;
    return \@datasets;
}

1;
