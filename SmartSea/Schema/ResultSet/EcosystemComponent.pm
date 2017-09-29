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
            next unless $rule->dataset->usable_in_rule;
            push @rules, $rule->read;
        }        
        push @layers, {
            id => $component->id,
            name => $component->name,
            owner => 'system',
            style => $component->style ? {
                palette => $component->style->palette->name,
                min => $component->style->min,
                max => $component->style->max,
            } : 'grayscale',
            rule_class => $component->distribution->rule_class->name,
            rules => \@rules};
    }
    return @layers if wantarray;
    return \@layers;
}

1;
