package SmartSea::Schema::ResultSet::Activity;

use strict; 
use warnings;

use base 'DBIx::Class::ResultSet';

sub impact_network {
    my ($self, $nodes, $edges) = @_;
    my %pressures;
    for my $activity ($self->all) {
        push @$nodes, { data => { id => 'a'.$activity->id, name => $activity->name }};
        for my $pressure_class ($activity->pressure_classes) {
            push @$edges, { data => { 
                source => 'a'.$activity->id, 
                target => 'p'.$pressure_class->id }};
            $pressures{$pressure_class->id} = $pressure_class->name;
        }
    }
    for my $id (keys %pressures) {
        push @$nodes, { data => { id => 'p'.$id, name => $pressures{$id} }};
    }
}

1;
