package SmartSea::Schema::Result::Use2Zoning;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id     => {},
    use    => {is_foreign_key => 1, source => 'Use', not_null => 1},
    zoning => {is_foreign_key => 1, source => 'Zoning', not_null => 1},
    weight => { data_type => 'double', has_default => 1 },
    );

__PACKAGE__->table('use2zoning');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(zoning => 'SmartSea::Schema::Result::Zoning');

sub name {
    my $self = shift;
    return $self->use->name;
}

1;
