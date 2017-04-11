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
__PACKAGE__->has_many(pressures => 'SmartSea::Schema::Result::Pressure', 'activity');
__PACKAGE__->many_to_many(pressure_classes => 'pressures', 'pressure_class');
__PACKAGE__->has_many(use_class2activity => 'SmartSea::Schema::Result::UseClass2Activity', 'use_class');
__PACKAGE__->many_to_many(use_classes => 'use_class2activity', 'activity');

sub attributes {
    return \%attributes;
}

sub children_listers {
    return { 
        pressures => {
            col => 'pressure_class',
            source => 'Pressure',
            ref_to_me => 'activity',
            class_name => 'Pressures',
            for_child_form => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->pressure_class->id} = 1;
                }
                my @objs;
                for my $obj ($self->{schema}->resultset('PressureClass')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return 0 if @objs == 0; # this activity causes all kinds of pressures already
                return drop_down(name => 'pressure_class', objs => \@objs);
            }
        }
    };
}

1;
