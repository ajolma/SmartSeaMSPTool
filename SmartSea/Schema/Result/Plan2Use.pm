package SmartSea::Schema::Result::Plan2Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('plan2use');
__PACKAGE__->add_columns(qw/ id plan use /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');

__PACKAGE__->has_many(layers => 'SmartSea::Schema::Result::Layer', 'plan2use');
__PACKAGE__->many_to_many(layer_classes => 'layers', 'layer_class');

sub class_name {
    return 'Use';
}

sub name {
    my $self = shift;
    return $self->use->name;
}

sub children_listers {
    return {layers => [layer => 0], list_activities => [activity => 0, 0]};
}

sub for_child_form {
    my ($self, $kind, $children, $args) = @_;
    if ($kind eq 'layers') {
        my %has;
        for my $obj (@$children) {
            $has{$obj->layer_class->id} = 1;
        }
        my @objs;
        for my $obj ($args->{schema}->resultset('LayerClass')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        return drop_down(name => 'layer_class', objs => \@objs);
    }
}

sub list_activities {
    my ($self) = @_;
    return $self->use->activities;
}

1;
