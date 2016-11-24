package SmartSea::Schema::Result::EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.ecosystem_components');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');

sub order {
    my $self = shift;
    return $self->id;
}

1;
