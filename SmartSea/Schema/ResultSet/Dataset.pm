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
        my $range = '';
        if (defined $dataset->style->min) {
            my $u = '';
            $u = ' '.$dataset->my_unit->name if $dataset->my_unit;
            $range = ' ('.$dataset->style->min."$u..".$dataset->style->max."$u)";
        }
        push @datasets, {
            name => $dataset->name,
            provenance => $dataset->lineage,
            descr => $dataset->descr,
            style => $dataset->style->color_scale->name.$range,
            id => $dataset->id, 
            use => 0, 
            rules => []};
    }
    return @datasets if wantarray;
    return \@datasets;
}

1;
