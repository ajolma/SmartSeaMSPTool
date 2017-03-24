package SmartSea::Schema::Result::LayerClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

__PACKAGE__->table('layer_classes');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(layers => 'SmartSea::Schema::Result::Layer', 'layer_class');
__PACKAGE__->many_to_many(uses => 'layer', 'use');

sub attributes {
    return {name => {input => 'text'}};
}

1;
