package SmartSea::Schema::Result::ImpactStrength;
use strict;
use warnings;
use 5.010000;
use utf8;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id              => {},
    recovery        => {data_type => 'text', html_size => 30},
    extent          => {data_type => 'text', html_size => 30},
    resilience      => {data_type => 'text', html_size => 30},
    temporal_extent => {data_type => 'text', html_size => 30},
    );

__PACKAGE__->table('impact_strengths');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

sub name {
    my $self = shift;
    return 
        'Palautuminen = '.($self->recovery//'').' ja/tai '.
        'Vaikutus ekosysteemiin = '.($self->extent//'').' ja/tai '.
        'Kyky sietää painetta = '.($self->resilience//'').' ja/tai '.
        'Ajallinen ulottuvuus = '.($self->temporal_extent//'');
}

1;
