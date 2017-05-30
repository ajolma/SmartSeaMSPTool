package SmartSea::Schema::ResultSet::Op;

use strict; 
use warnings;
use SmartSea::Core qw(:all);

use base 'DBIx::Class::ResultSet';

sub tree {
    my ($self) = @_;
    my @items;
    for my $item ($self->search(undef, {order_by => {-asc => 'name'}})) {
        push @items, {id => $item->id, name => $item->name};
    }
    return \@items;
}

1;
