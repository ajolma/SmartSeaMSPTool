package SmartSea::Schema::Result::Belief;
use strict;
use warnings;
use 5.010000;
use utf8;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id          => {},
    value       => {data_type => 'integer', html_size => 30, has_default => 1},
    description => {data_type => 'text', html_size => 30}
    );

__PACKAGE__->table('beliefs');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

sub name {
    my $self = shift;
    return $self->description//'';
}

1;
