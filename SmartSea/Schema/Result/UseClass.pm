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
    return {name => {i => 0, input => 'text'}};
}

sub children_listers {
    return {
        activities => {
            col => 'activity',
            source => 'Activity',
            link_source => 'UseClass2Activity',
            ref_to_me => 'use_class',
            ref_to_child => 'activity',
            class_name => 'Activities', 
            editable_children => 0,
            for_child_form => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->id} = 1;
                }
                my @objs;
                for my $obj ($self->{schema}->resultset('Activity')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'activity', objs => \@objs);
            }
        }
    };
}

sub need_form_for_child {
    my ($class, $child_source) = @_;
    return 1 if $child_source eq 'Use'; # plan needs to be asked from the user
    return 0; # link to Activity can be created directly
}

1;
