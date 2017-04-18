package SmartSea::Schema::Result::ImpactStrength;
use strict;
use warnings;
use 5.010000;
use utf8;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('impact_strengths');
__PACKAGE__->add_columns(qw/id recovery extent resilience temporal_extent/);
__PACKAGE__->set_primary_key('id');

sub attributes {
    return {
        recovery => {i => 0, input => 'text'},
        extent => {i => 0, input => 'text'},
        resilience => {i => 0, input => 'text'},
        temporal_extent => {i => 0, input => 'text'},
    };
}

sub name {
    my $self = shift;
    return 
        'Palautuminen = '.($self->recovery//'').' ja/tai '.
        'Vaikutus ekosysteemiin = '.($self->extent//'').' ja/tai '.
        'Kyky sietää painetta = '.($self->resilience//'').' ja/tai '.
        'Ajallinen ulottuvuus = '.($self->temporal_extent//'');
}

1;
