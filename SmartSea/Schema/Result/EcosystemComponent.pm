package SmartSea::Schema::Result::EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

__PACKAGE__->table('ecosystem_components');
__PACKAGE__->add_columns(qw/ id name dataset /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'ecosystem_component');
__PACKAGE__->belongs_to(dataset => 'SmartSea::Schema::Result::Dataset');

sub attributes {
    return {
        name => {
            i => 0,
            input => 'text',
        },
        dataset => {
            i => 1,
            input => 'lookup',  
            source => 'Dataset', 
            objs => {path => {'!=',undef}}
        }
    };
}

sub order {
    my $self = shift;
    return $self->id;
}

1;
