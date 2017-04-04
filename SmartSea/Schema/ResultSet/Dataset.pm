package SmartSea::Schema::ResultSet::Dataset;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub list {
    my $self = shift;
    $self->search({ -and => [is_a_part_of => undef, is_derived_from => undef] }, {order_by => {-asc => 'name'}});
}

sub parts {
    my ($self, $of) = @_;
    $self->search({is_a_part_of => $of->id});
}

sub derivatives {
    my ($self, $of) = @_;
    $self->search({is_derived_from => $of->id});
}

1;
