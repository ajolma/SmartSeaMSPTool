package SmartSea::Schema::Result::Plan2DatasetExtra;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('plan2dataset_extra');
__PACKAGE__->add_columns(qw/ id plan dataset /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(dataset => 'SmartSea::Schema::Result::Dataset');

sub name {
    my ($self) = @_;
    return $self->plan->name . ' -> ' . $self->dataset->name;
}

sub attributes {
    return {
        plan => { i => 0, input => 'lookup', source => 'Plan' },
        dataset => { i => 1, input => 'lookup', source => 'Dataset' },
    };
}

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return {} unless $parent;
    return {plan => $parent->id, dataset => $parameters->{extra_dataset}};
}

1;
