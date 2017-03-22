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
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'plan');
__PACKAGE__->many_to_many(uses => 'plan2use', 'use');

sub attributes {
    return \%attributes;
}

sub children_listers {
    return {plan2use => [plan2use => 0]};
}

sub for_child_form {
    my ($self, $kind, $children, $args) = @_;
    if ($kind eq 'plan2use') {
        my %has;
        for my $obj (@$children) {
            $has{$obj->use->id} = 1;
        }
        my @objs;
        for my $obj ($args->{schema}->resultset('Plan2Use')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        return drop_down(name => 'plan2use', objs => \@objs);
    }
}

1;
