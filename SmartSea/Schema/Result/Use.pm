package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id        => {},
    plan      => {is_foreign_key => 1, source => 'Plan', parent => 1, not_null => 1},
    use_class => {is_foreign_key => 1, source => 'UseClass', not_null => 1},
    owner     => {}
    );

__PACKAGE__->table('uses');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use_class => 'SmartSea::Schema::Result::UseClass');
__PACKAGE__->has_many(layers => 'SmartSea::Schema::Result::Layer', 'use');
__PACKAGE__->many_to_many(layer_classes => 'layers', 'layer_class');

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my ($self) = @_;
    return ($self->plan->name//'').'.'.($self->use_class->name//'');
}

sub relationship_hash {
    return {
        layers => {
            name => 'Layer',
            source => 'Layer',
            ref_to_parent => 'use',
            class_column => 'layer_class',
            class_widget => sub {
                my ($self, $children) = @_;
                my %has;
                for my $obj (@$children) {
                    $has{$obj->layer_class->id} = 1;
                }
                my @objs;
                for my $obj ($self->{app}{schema}->resultset('LayerClass')->all) {
                    next if $has{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'layer_class', objs => \@objs);
            }
        },
        activities => {
            source => 'Activity',
            no_edit => 1 # through use class
        },
        ecosystem_impacts => {
            name => 'Ecosystem impact',
            source => 'EcosystemComponent',
            no_edit => 1 # computed
        }
    };
}

sub activities {
    my ($self) = @_;
    return $self->use_class->activities;
}

sub read {
    my ($self) = @_;
    my @layers;
    for my $layer ($self->layers(undef, {order_by => {-desc => 'id'}})) {
        push @layers, $layer->read;
    }
    return {
        id => $self->id,
        class_id => $self->use_class->id,
        plan => $self->plan->id,
        owner => $self->owner,
        name => $self->use_class->name, 
        layers => \@layers
    }
}

sub ecosystem_impacts {
    my ($self) = @_;
    my %impacts;
    my %components;
    my %ranges;
    # compute the sum of pdf's for all components and ranges
    for my $activity ($self->use_class->activities) {
        for my $pressure ($activity->pressures) {
            my $range = $pressure->range->d;
            $range = 1.0e10 if $range eq 'Infinity';
            $ranges{$range} //= $pressure->range->name;
            for my $impact ($pressure->impacts) {
                my $component = $impact->ecosystem_component;
                my $name = $component->name;
                $components{$name} //= $component;
                $impacts{$name}{$range} =
                    defined $impacts{$name}{$range} ?
                    $impact->pdf_sum($impacts{$name}{$range}) :
                    $impact->pdf;
            }
        }
    }
    # compute the expected value for all components and ranges
    # the expected value of smaller range is that of larger range if that has greater expected value
    my $impact_class = 'SmartSea::Schema::Result::Impact';
    my %expected_values;
    for my $name (keys %components) {
        my $expected_value;
        for my $range (sort {$b <=> $a} keys %{$impacts{$name}}) {
            my $e = $impact_class->expected_value($impacts{$name}{$range});
            if (!defined($expected_value)) {
                $expected_value = $e;
            } else {
                if ($expected_value < $e) {
                    $expected_value = $e;
                } else {
                    $e = $expected_value;
                }
            }
            $expected_values{$name}{$range} = $e;
        }
    }
    my @impacts;
    for my $name (sort keys %components) {
        my @i;
        for my $range (sort {$a <=> $b} keys %{$expected_values{$name}}) {
            my $e = $expected_values{$name}{$range};
            $e = sprintf("%.2f", $e);
            push @i, "$ranges{$range}: $e";
        }
        # call below will not update db unless insert or update is called and it is not
        $components{$name}->name($name.": ".join(', ', @i));
        push @impacts, $components{$name};
    }
    return @impacts;
}

1;
