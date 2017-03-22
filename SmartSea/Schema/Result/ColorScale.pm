package SmartSea::Schema::Result::ColorScale;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('color_scales');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

sub attributes {
    return {name => {input => 'text'}};
}

sub li {
    my ($self) = @_;
    return [li=>[[b=>'Color scale: '],[0=>$self->name]]];
}

1;
