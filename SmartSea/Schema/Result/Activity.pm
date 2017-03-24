package SmartSea::Schema::Result::Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my %attributes = (
    name =>  { i => 1,  input => 'text',  size => 20 },
    ordr =>  { i => 2,  input => 'text',  size => 10 },
    );

__PACKAGE__->table('activities');
__PACKAGE__->add_columns(qw/ id ordr name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'activity');
__PACKAGE__->many_to_many(pressures => 'activity2pressure', 'pressure');
__PACKAGE__->has_many(use_class2activity => 'SmartSea::Schema::Result::UseClass2Activity', 'use_class');
__PACKAGE__->many_to_many(use_classes => 'use_class2activity', 'activity');

sub attributes {
    return \%attributes;
}

sub children_listers {
    return { activity2pressure => [activity2pressure => 0] }; # todo: activity2pressure here
}

1;
