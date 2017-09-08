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
    name  => {data_type => 'text', html_size => 30, not_null => 1},
    owner => {}
    );

__PACKAGE__->table('plans');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(uses => 'SmartSea::Schema::Result::Use', 'plan');
__PACKAGE__->many_to_many(use_classes => 'uses', 'use_class');

__PACKAGE__->has_many(extras => 'SmartSea::Schema::Result::Plan2DatasetExtra', 'plan');
__PACKAGE__->many_to_many(extra_datasets => 'extras', 'dataset');

__PACKAGE__->has_many(zonings => 'SmartSea::Schema::Result::Zoning', 'plan');

sub relationship_hash {
    return {
        uses => {
            source => 'Use',
            ref_to_parent => 'plan',
            class_column => 'use_class',
            class_widget => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->use_class->id} = 1;
                }
                my @objs;
                for my $obj ($self->{app}{schema}->resultset('UseClass')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'use_class', objs => \@objs);
            }
        },
        extra_datasets => {
            name => 'Extra dataset',
            source => 'Dataset',
            link_objects => 'extras',
            link_source => 'Plan2DatasetExtra',
            ref_to_parent => 'plan',
            ref_to_related => 'dataset',
            stop_edit => 1,
            class_column => 'dataset',
            class_widget => sub {
                my ($self, $children) = @_;
                my $has = $self->{row}->datasets($self);
                for my $obj (@$children) {
                    $has->{$obj->id} = 1;
                }
                my @objs;
                for my $obj ($self->{app}{schema}->resultset('Dataset')->search({path => { '!=', undef }})) {
                    next if $has->{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'dataset', objs => \@objs);
            }
        },
        zonings => {
            name => 'Zonings',
            source => 'Zoning',
            ref_to_parent => 'plan',
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
        my $use = $args->{app}{schema}->
            resultset('Use')->
            single({plan => $self->id, use_class => $use_class->id});
        for my $layer_class ($use->layer_classes) {
            my $layer = $args->{app}{schema}->
                resultset('Layer')->
                single({use => $use->id, layer_class => $layer_class->id});
            for my $rule ($layer->rules({cookie => ''})) {
                $datasets{$rule->dataset->id} = $rule->dataset if $rule->dataset;
            }
        }
    }
    return \%datasets;
}

sub read {
    my $self = shift;
    my @uses;
    my %data;
    for my $use ($self->uses(undef, {order_by => 'id'})) {
        push @uses, $use->read;
    }
    for my $dataset ($self->extra_datasets) {
        $data{$dataset->id} = 1 if $dataset->usable_in_rule;
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
