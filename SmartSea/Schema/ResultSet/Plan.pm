package SmartSea::Schema::ResultSet::Plan;

use strict; 
use warnings;
use SmartSea::Core qw(:all);

use base 'DBIx::Class::ResultSet';

# plans -> uses -> layers
# ids of uses and layers are class ids
sub read {
    my ($self) = @_;
    my @plans;
    for my $plan ($self->search(undef, {order_by => {-desc => 'name'}})) {
        push @plans, $plan->read;
    }
    return \@plans;
}

1;
