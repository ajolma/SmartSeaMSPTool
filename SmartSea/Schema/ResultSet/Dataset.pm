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
        #say STDERR $dataset->id;
        next unless $dataset->path;
        next unless $dataset->style;
        push @datasets, $dataset->tree;
    }
    return @datasets if wantarray;
    return \@datasets;
}

sub tree {
    my ($self, $parameters) = @_;
    my @rows;
    my $search;
    if ($parameters->{path}) {
        $search = {path => { '!=', undef }};
    }
    for my $row ($self->search($search, {order_by => {-asc => 'name'}})) {
        push @rows, $row->tree;
    }
    return \@rows;
}

1;
