package SmartSea::Schema::Result::UseClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('use_classes');
__PACKAGE__->add_columns('id', 'name');
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(use => 'SmartSea::Schema::Result::Use', 'use_class');
__PACKAGE__->many_to_many(plans => 'use', 'plan');

__PACKAGE__->has_many(use_class2activity => 'SmartSea::Schema::Result::UseClass2Activity', 'use_class');
__PACKAGE__->many_to_many(activities => 'use_class2activity', 'activity');

sub attributes {
    return {name => {input => 'text'}};
}

sub children_listers {
    return {activities => [activity => 0]};
}

sub for_child_form {
    my ($self, $kind, $children, $args) = @_;
    if ($kind eq 'activities') {
        my %has;
        for my $obj (@$children) {
            $has{$obj->id} = 1;
        }
        my @objs;
        for my $obj ($args->{schema}->resultset('Activity')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        return drop_down(name => 'activity', objs => \@objs);
    }
}

1;
