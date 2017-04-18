package SmartSea::Schema::Result::Belief;
use strict;
use warnings;
use 5.010000;
use utf8;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('beliefs');
__PACKAGE__->add_columns(qw/ id description /);
__PACKAGE__->set_primary_key('id');

sub attributes {
    return {
        id => {i => 0, input => 'text', size => 10},
        description => {i => 1, input => 'text', size => 30}
    };
}

sub name {
    my $self = shift;
    return $self->description//'';
}

1;
