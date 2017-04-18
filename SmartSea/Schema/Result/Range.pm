package SmartSea::Schema::Result::Range;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('ranges');
__PACKAGE__->add_columns(qw/id d/);
__PACKAGE__->set_primary_key('id');

sub attributes {
    return {d => {i => 0, input => 'text'}};
}

sub name {
    my $self = shift;
    my $d = $self->d;
    return '> 20 km' if $d eq 'Infinity';
    my $unit = 'm';
    if ($d >= 1000) {
        $d /= 1000;
        $unit = 'km';
    }
    return "< $d $unit";
}

1;
