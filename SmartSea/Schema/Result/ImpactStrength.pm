package SmartSea::Schema::Result::ImpactStrength;
use strict;
use warnings;
use 5.010000;
use utf8;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id              => {},
    value           => {data_type => 'text', html_size => 20},
    recovery        => {data_type => 'text', html_size => 30},
    extent          => {data_type => 'text', html_size => 30},
    resilience      => {data_type => 'text', html_size => 30},
    temporal_extent => {data_type => 'text', html_size => 30},
    );

__PACKAGE__->table('impact_strengths');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

my %translations = (
    recovery => 'Palautuminen',
    extent => 'Vaikutus',
    resilience => 'Kyky sietää painetta',
    temporal_extent => 'Ajallinen ulottuvuus'
);

sub name {
    my $self = shift;
    my @name;
    for my $key (qw/recovery extent resilience temporal_extent/) {
        push @name, $translations{$key}.': '.$self->$key if $self->$key;
    }
    return join(', ', @name);
}

1;
