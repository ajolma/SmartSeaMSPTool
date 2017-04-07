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
    return $self->dataset->name;
}

1;
