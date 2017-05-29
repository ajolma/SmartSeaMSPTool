package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my @columns = (
    id    => {},
    name  => {data_type => 'text', html_size => 30},
    owner => {}
    );

__PACKAGE__->table('plans');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(uses => 'SmartSea::Schema::Result::Use', 'plan');
__PACKAGE__->many_to_many(use_classes => 'uses', 'use_class');

__PACKAGE__->has_many(extras => 'SmartSea::Schema::Result::Plan2DatasetExtra', 'plan');
__PACKAGE__->many_to_many(extra_datasets => 'extras', 'dataset');

sub children_listers {
    return {
        uses => {
            col => 'use_class',
            source => 'Use',
            ref_to_me => 'plan',
            class_name => 'Uses',
            child_is_mine => 1,
            for_child_form => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->use_class->id} = 1;
                }
                my @objs;
                for my $obj ($self->{client}{schema}->resultset('UseClass')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'use_class', objs => \@objs);
            }
        },
        extra_datasets => {
            col => 'extra_dataset',
            source => 'Dataset',
            link_source => 'Plan2DatasetExtra',
            ref_to_me => 'plan',
            ref_to_child => 'dataset',
            class_name => 'Extra datasets',
            editable_children => 0,
            for_child_form => sub {
                my ($self, $children) = @_;
                my $has = $self->{object}->datasets($self);
                for my $obj (@$children) {
                    $has->{$obj->id} = 1;
                }
                my @objs;
                for my $obj ($self->{client}{schema}->resultset('Dataset')->search({path => { '!=', undef }})) {
                    next if $has->{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'extra_dataset', objs => \@objs);
            }
        }
    };
}

sub need_form_for_child {
    my ($class, $child_source) = @_;
    return 0; # Use and Dataset are simple links
}

# datasets referenced by this plan through rules
sub datasets {
    my ($self, $args) = @_;
    my %datasets;
    for my $use_class ($self->use_classes) {
        my $use = $args->{client}{schema}->
            resultset('Use')->
            single({plan => $self->id, use_class => $use_class->id});
        for my $layer_class ($use->layer_classes) {
            my $layer = $args->{client}{schema}->
                resultset('Layer')->
                single({use => $use->id, layer_class => $layer_class->id});
            for my $rule ($layer->rules({cookie => DEFAULT})) {
                $datasets{$rule->r_dataset->id} = $rule->r_dataset if $rule->r_dataset;
            }
        }
    }
    return \%datasets;
}

sub tree {
    my $self = shift;
    my @uses;
    my %data;
    for my $use ($self->uses(undef, {order_by => 'id'})) {
        my @layers;
        for my $layer ($use->layers(undef, {order_by => {-desc => 'id'}})) {
            my @rules;
            for my $rule (sort {$a->name cmp $b->name} $layer->rules({cookie => DEFAULT})) {
                push @rules, $rule->as_hashref_for_json;
                $data{$rule->r_dataset->id} = 1 if $rule->r_dataset;
            }
            push @layers, {
                owner => $layer->owner,
                name => $layer->layer_class->name,
                style => $layer->style->color_scale->name,
                id => $layer->layer_class->id,
                use => $use->use_class->id,
                rule_class => $layer->rule_system->rule_class->name,
                rules => \@rules};
        }
        push @uses, {
            owner => $use->owner,
            name => $use->use_class->name, 
            id => $use->use_class->id,
            layers => \@layers
        };
    }
    for my $dataset ($self->extra_datasets) {
        $data{$dataset->id} = 1 if $dataset->path;
    }
    return {
        owner => $self->owner,
        name => $self->name, 
        id => $self->id, 
        uses => \@uses, 
        data => \%data
    };
}

1;
