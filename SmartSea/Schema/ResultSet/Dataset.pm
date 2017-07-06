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
        next unless $dataset->path;
        next unless $dataset->style;
        next unless $dataset->data_type;
        push @datasets, $dataset->tree;
    }
    return @datasets if wantarray;
    return \@datasets;
}

1;
