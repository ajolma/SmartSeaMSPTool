package SmartSea::Schema::Result::Range;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id => {},
    d  => {data_type => 'text', html_size => 30, required => 1}
    );

__PACKAGE__->table('ranges');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

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
