package SmartSea::Schema::ResultSet::EcosystemComponent;

use strict; 
use warnings;
use SmartSea::Core qw(:all);

use base 'DBIx::Class::ResultSet';

# a layers for a "plan"
sub layers {
    my ($self) = @_;
    my @layers;
    for my $component ($self->search(undef, {order_by => {-asc => 'name'}})->all) {
        next unless $component->distribution;
        next unless $component->style;
        my @rules;
        for my $rule (sort {$a->name cmp $b->name} $component->rules({cookie => ''})) {
            push @rules, $rule->read;
        }        
        push @layers, {
            name => $component->name,
            id => $component->id, 
            use_class_id => 1, # reserved use class id
            rules => \@rules};
    }
    return @layers if wantarray;
    return \@layers;
}

1;
