package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

__PACKAGE__->table('plans');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(uses => 'SmartSea::Schema::Result::Use', 'plan');
__PACKAGE__->many_to_many(use_classes => 'uses', 'use_class');

__PACKAGE__->has_many(extras => 'SmartSea::Schema::Result::Plan2DatasetExtra', 'plan');
__PACKAGE__->many_to_many(extra_datasets => 'extras', 'dataset');

sub attributes {
    return {name => {i => 0, input => 'text'}};
}

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
                for my $obj ($self->{schema}->resultset('UseClass')->all) {
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
                for my $obj ($self->{schema}->resultset('Dataset')->search({path => { '!=', undef }})) {
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
        my $use = $args->{schema}->
            resultset('Use')->
            single({plan => $self->id, use_class => $use_class->id});
        for my $layer_class ($use->layer_classes) {
            my $layer = $args->{schema}->
                resultset('Layer')->
                single({use => $use->id, layer_class => $layer_class->id});
            for my $rule ($layer->rules({cookie => DEFAULT})) {
                $datasets{$rule->r_dataset->id} = $rule->r_dataset if $rule->r_dataset;
            }
        }
    }
    return \%datasets;
}

1;
