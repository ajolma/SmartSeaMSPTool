package SmartSea::Schema::Result::Plan2DatasetExtra;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

my @columns = (
    id      => {},
    plan    => { is_foreign_key => 1, source => 'Plan' },
    dataset => { is_foreign_key => 1, source => 'Dataset' },
    );

__PACKAGE__->table('plan2dataset_extra');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(dataset => 'SmartSea::Schema::Result::Dataset');

sub name {
    my ($self) = @_;
    return $self->plan->name . ' -> ' . $self->dataset->name;
}

sub column_values_from_context {
    my ($self, $parent) = @_;
    return {plan => $parent->id, dataset => $self->dataset->id};
}

1;
