package SmartSea::Schema::Result::Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id   =>  {},
    name =>  { data_type => 'text', html_size => 20, not_null => 1 },
    ordr =>  { data_type => 'text', html_size => 10, not_null => 1, empty_is_default => 1 },
    );

__PACKAGE__->table('activities');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(pressures => 'SmartSea::Schema::Result::Pressure', 'activity');
__PACKAGE__->many_to_many(pressure_classes => 'pressures', 'pressure_class');
__PACKAGE__->has_many(use_class2activity => 'SmartSea::Schema::Result::UseClass2Activity', 'use_class');
__PACKAGE__->many_to_many(use_classes => 'use_class2activity', 'activity');

sub relationship_hash {
    return { 
        pressures => {
            source => 'Pressure',
            ref_to_parent => 'activity',
            class_column => 'pressure_class',
            class_widget => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->pressure_class->id} = 1;
                }
                my @objs;
                for my $obj ($self->{app}{schema}->resultset('PressureClass')->search(undef, {order_by => 'ordr'})) {
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
