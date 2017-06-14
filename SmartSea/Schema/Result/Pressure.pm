package SmartSea::Schema::Result::Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id             => {},
    range          => {is_foreign_key => 1, source => 'Range', not_null => 1},
    activity       => {is_foreign_key => 1, source => 'Activity', parent => 1, not_null => 1},
    pressure_class => {is_foreign_key => 1, source => 'PressureClass', not_null => 1}
    );

__PACKAGE__->table('pressures');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');
__PACKAGE__->belongs_to(pressure_class => 'SmartSea::Schema::Result::PressureClass');
__PACKAGE__->belongs_to(range => 'SmartSea::Schema::Result::Range');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'pressure');

sub order_by {
    return {-asc => 'id'};
}

sub relationship_hash {
    return { 
        impacts => {
            source => 'Impact',
            ref_to_parent => 'pressure',
            class_column => 'ecosystem_component',
            class_widget => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->ecosystem_component->id} = 1;
                }
                my @objs;
                for my $obj ($self->{app}{schema}->resultset('EcosystemComponent')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return 0 if @objs == 0; # all ecosystem components have already an impact
                return drop_down(name => 'ecosystem_component', objs => \@objs);
            }
        } 
    };
}

sub column_values_from_context {
    my ($self, $parent) = @_;
    my %retval = (activity => $parent->id);
    $retval{pressure_class} = $self->pressure_class->id if ref $self;
    return \%retval;
}

sub name {
    my ($self) = @_;
    return ($self->activity->name//'').' -> '.($self->pressure_class->name//'');
}

1;
