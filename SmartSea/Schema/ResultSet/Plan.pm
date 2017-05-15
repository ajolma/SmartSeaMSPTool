package SmartSea::Schema::ResultSet::Plan;

use strict; 
use warnings;
use SmartSea::Core qw(:all);

use base 'DBIx::Class::ResultSet';

# plans -> uses -> layers
# ids of uses and layers are class ids
sub array_of_trees {
    my ($self) = @_;
    my @plans;
    for my $plan ($self->search(undef, {order_by => {-desc => 'name'}})) {
        my @uses;
        my %data;
        for my $use ($plan->uses(undef, {order_by => 'id'})) {
            my @layers;
            for my $layer ($use->layers(undef, {order_by => {-desc => 'id'}})) {
                my @rules;
                for my $rule (sort {$a->name cmp $b->name} $layer->rules({cookie => DEFAULT})) {
                    push @rules, $rule->as_hashref_for_json;
                    $data{$rule->r_dataset->id} = 1 if $rule->r_dataset;
                }
                push @layers, {
                    name => $layer->layer_class->name,
                    style => $layer->style->color_scale->name,
                    id => $layer->layer_class->id,
                    use => $use->use_class->id,
                    rule_class => $layer->rule_system->rule_class->name,
                    rules => \@rules};
            }
            push @uses, {
                name => $use->use_class->name, 
                id => $use->use_class->id,
                layers => \@layers
            };
        }
        for my $dataset ($plan->extra_datasets) {
            $data{$dataset->id} = 1 if $dataset->path;
        }
        push @plans, {
            name => $plan->name, 
            id => $plan->id, 
            uses => \@uses, 
            data => \%data
        };
    }
    return \@plans;
}

1;
