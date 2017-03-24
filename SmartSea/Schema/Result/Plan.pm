package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';

use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my %attributes = (
    name =>            { i => 1,  input => 'text',    size => 20 },
    );

__PACKAGE__->table('plans');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(uses => 'SmartSea::Schema::Result::Use', 'plan');
__PACKAGE__->many_to_many(use_classes => 'use', 'use_class');

sub attributes {
    return \%attributes;
}

sub children_listers {
    return {uses => [use => 0]};
}

sub for_child_form {
    my ($self, $kind, $children, $args) = @_;
    if ($kind eq 'uses') {
        my %has;
        for my $obj (@$children) {
            $has{$obj->use_class->id} = 1;
        }
        my @objs;
        for my $obj ($args->{schema}->resultset('UseClass')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        return drop_down(name => 'use', objs => \@objs);
    }
}

1;
