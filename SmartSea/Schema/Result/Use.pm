package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('uses');
__PACKAGE__->add_columns(qw/ id plan use_class /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use_class => 'SmartSea::Schema::Result::UseClass');
__PACKAGE__->has_many(layers => 'SmartSea::Schema::Result::Layer', 'use');
__PACKAGE__->many_to_many(layer_classes => 'layers', 'layer_class');

sub order_by {
    return {-asc => 'id'};
}

sub attributes {
    return {plan => {input => 'ignore'}, use_class => {input => 'ignore'}};
}

sub name {
    my ($self) = @_;
    return $self->plan->name.'.'.$self->use_class->name;
}

sub children_listers {
    return {
        layers => {
            source => 'Layer',
            ref_to_me => 'use',
            class_name => 'Layers',
            for_child_form => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->layer_class->id} = 1;
                }
                my @objs;
                for my $obj ($self->{schema}->resultset('LayerClass')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'layer_class', objs => \@objs);
            }
        },
        activities => {
            source => 'Activity', 
            class_name => 'Activities', 
            editable_children => 0,
            cannot_add_remove_children => 1,
            for_child_form => sub {
                my ($self, $children) = @_;
                return undef;
            }
        }
    };
}

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {} unless $parent;
    return {plan => $parent->id, use_class => $parameters->{use_class}};
}

sub activities {
    my ($self) = @_;
    return $self->use_class->activities;
}

1;
