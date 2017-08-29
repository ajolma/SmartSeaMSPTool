package SmartSea::Layer;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use PDL;
use SmartSea::Schema::Result::NumberType qw(:all);
use SmartSea::Schema::Result::RuleClass qw(:all);
use SmartSea::Core qw(:all);

# A WMTS layer, which is in this system either
# 0: a dataset,
# 1: distribution & abundance of an ecosystem component or some other ecosystem indicator, or
# 2: a spatial value computed from those
#
# Also the ecosystem value is computed from a dataset or datasets.
# Computing is based on rules.
# 
# The trail (below) is (0|1|2)_id[_rule-id...]
#
# From visualization point of view this is a raster source.
# The raster is either continuous data or classed data.
# Data has min and max (for classed data these are integers).
# Min and max can be overridden in associated Style object.
#
# Rules do not have any specific order.

# attributes in self when calling:
# configuration variables: schema, data_dir
# what the layer is: trail
# what to make: tile, epsg
# how to make it: mask, palette, min, max (not yet implemented)
sub new {
    my ($class, $self) = @_;
    $self->{debug} //= 0;
    
    my ($type, $id, @rules) = split /_/, $self->{trail} // '';
    #return bless $self, $class unless $id;

    $type //= 0;
    $id //= 0;
    # 'duck' since the different types are conceptually subclasses
    if ($type == 0) {
        # dataset is really not viewable unless its min, max and data type have been set
        $self->{duck} = $self->{schema}->resultset('Dataset')->single({ id => $id });
        croak "Dataset $id does not exist.\n" unless $self->{duck};
        # min, max, and data type really should have been set
        $self->{min} = $self->{duck}->min_value // 0;
        $self->{max} = $self->{duck}->max_value // 1;
        $self->{min} = $self->{max} if $self->{min} > $self->{max};
        if (my $t = $self->{duck}->data_type) {
            $self->{data_type} = $t->id;
        } else {
            $self->{data_type} = INTEGER_NUMBER; # wild guess
        }
        my $unit = $self->{duck}->unit;
        $self->{unit} = defined $unit ? $unit->name : '';
        if ($self->{duck}->semantics) {
            $self->{labels} = $self->{duck}->semantics_hash;
        } elsif ($self->{min} == $self->{max}) {
            #$self->{labels} = jotain;
        }
        
    } elsif ($type == 1) {
        $self->{duck} = $self->{schema}->resultset('EcosystemComponent')->single({ id => $id });
        croak "Ecosystem component $id does not exist!" unless $self->{duck};
        $self->{min} = 1;
        $self->{max} = 1;
        $self->{data_type} = INTEGER_NUMBER;
        #$self->{labels} = jotain;
        %{$self->{rules}} = map {$_ => 1} @rules;
        
    } else {
        $self->{duck} = $self->{schema}->resultset('Layer')->single({ id => $id });
        croak "Layer $id does not exist!" unless $self->{duck};
        $self->{labels} = $self->{duck}->layer_class->semantics_hash;
        %{$self->{rules}} = map {$_ => 1} @rules;
        
    }

    # get the rules
    if ($self->{rules}) {

        my $system = $self->{duck}->rule_system;
        my $class = $system->rule_class->id;
        if ($class == EXCLUSIVE_RULE or $class == INCLUSIVE_RULE) {
            # result is 1 or nodata
            $self->{min} = 1;
            $self->{max} = 1;
            $self->{data_type} = INTEGER_NUMBER;
        } elsif ($class == MULTIPLICATIVE_RULE or $class == ADDITIVE_RULE) {
            # result is a floating point value or nodata
            $self->{min} = 0;
            $self->{max} = 1;
            $self->{data_type} = REAL_NUMBER;
        } elsif ($class == BOXCAR_RULE || $class == BAYESIAN_NETWORK_RULE) {
            # min and max are obtained from rules below (for boxcar)
            # fixme: case of legend: rules need to be set
            $self->{min} = 0;
            $self->{max} = 1;
            $self->{data_type} = REAL_NUMBER;
        } else {
            croak "Unknown rule class: $class.";
        }

        if ($class == BOXCAR_RULE) {
            my $sum_of_pos_weights = 0;
            my $sum_of_neg_weights = 0;
            for my $rule ($system->active_rules($self)) {
                if ($rule->weight > 0) {
                    $sum_of_pos_weights += $rule->weight;
                } else {
                    $sum_of_neg_weights += $rule->weight;
                }
            }
            $self->{min} = $sum_of_neg_weights;
            $self->{max} = $sum_of_pos_weights;
        }

        say STDERR "layer rules: $class [$self->{min}..$self->{max}], $self->{data_type}" if $self->{debug};
    }

    # fixme: at this point we must have a style
    # if it is not then we should assign a temporary one
    $self->{duck}->style(SmartSea::Layer::Style->new()) unless $self->{duck}->style;

    # todo: override style here
    # palette, min, max

    return bless $self, $class;
}

sub id {
    my ($self) = @_;
    return $self->{duck}->id;
}

{
    package SmartSea::Layer::Palette;
    use base qw/SmartSea::Schema::Result::Palette/;
    sub new {
        my ($class, $self) = @_;
        $self->{id} = 0;
        $self->{name} //= 'grayscale';
        return bless $self, $class;
    }
    sub name {
        my $self = shift;
        return $self->{name};
    }
}

{
    package SmartSea::Layer::Style;
    use base qw/SmartSea::Schema::Result::Style/;
    sub new {
        my ($class, $self) = @_;
        $self->{id} = 0;
        $self->{palette} = SmartSea::Layer::Palette->new({name => $self->{palette}});
        return bless $self, $class;
    }
    sub id {
        my $self = shift;
        return $self->{id};
    }
    sub min {
        my ($self, $min) = @_;
        $self->{min} //= $min;
        return $self->{min};
    }
    sub max {
        my ($self, $max) = @_;
        $self->{max} //= $max;
        return $self->{max};
    }
    sub palette {
        my ($self, $palette) = @_;
        $self->{palette} //= $palette;
        return $self->{palette};
    }
    sub classes {
        my ($self, $value) = @_;
        $self->{classes} //= $value;
        return $self->{classes};
    }
}

sub legend {
    my ($self, $args) = @_;
    $args->{data_type} = $self->{data_type};
    $args->{min} = $self->{min};
    $args->{max} = $self->{max};
    $args->{unit} = $self->{unit};
    $args->{labels} = $self->{labels};
    return $self->{duck}->style->legend($args);
}

sub compute {
    my ($self) = @_;

    my $y;

    if ($self->{rules}) {
        my $system = $self->{duck}->rule_system;
        my $method = $system->rule_class->id;
        say STDERR "compute layer, method => $method" if $self->{debug};
        
        $y = zeroes($self->{tile}->size);
        $y += 1 if $method == EXCLUSIVE_RULE || $method == MULTIPLICATIVE_RULE;
    
        $system->compute($y, $self);

    } else {
        # we know duck is a dataset
        my $band;
        eval {
            $band = $self->{duck}->Band($self);
        };
        if ($@) {
            $y = zeroes($self->{tile}->size);
            $y = $y->setbadif($y == 0);
        } else {
            $y = $band->Piddle;
        
            # this is a hack
            my $bad = $band->NoDataValue();
            if (defined $bad) {
                if ($bad < -1000) {
                    $y = $y->setbadif($y < -1000);
                } elsif ($bad > 1000) {
                    $y = $y->setbadif($y > 1000);
                } else {
                    $y = $y->setbadif($y == $bad);
                }
            }
        }
        if ($self->{debug} > 1) {
            my @stats = stats($y); # 3 and 4 are min and max
            say STDERR "Dataset ",$self->{duck}->name," min=$stats[3], max=$stats[4]";
        }
        
    }

    my $result = $self->mask();
    
    my $mask = $result->Band->Piddle; # 1 = target area, 0 not
    $mask->inplace->setvaltobad(0);
        
    $y *= $mask;

    my $style = $self->{duck}->style;

    # combine data min and max to min and max possibly set in style
    # and obtain number of classes for visualization
    # if classes == 1, all zero cells get color 0 and non-zero cells get color 1
    $style->prepare($self);

    if ($style->classes == 1) {

        $y->where($y != 0) .= 1;
        
    } else {

        my $divisor = $style->max - $style->min;
        if ($divisor != 0) {
            my $k = $style->classes / $divisor;
            my $c = $style->min * $k;
            say STDERR "[".$style->min."..".$style->max."] to ".$style->classes." classes".
                ", k = $k, b = $c" if $self->{debug};
      
            $y = double $y;
            $y *= $k;
            $y -= $c;
            $y = $y->clip(0, $style->classes - 1);
        }
    }

    if ($self->{debug} > 1) {
        my @stats = stats($y); # 3 and 4 are min and max
        say STDERR "Result min=$stats[3], max=$stats[4]";
    }

    $y->inplace->setbadtoval(255);
    $result->Band->Piddle(byte $y);
    $result->Band->ColorTable($style->palette->color_table($style->classes));
    return $result
}

sub mask { 
    my $self = shift;
    my $tile = $self->{tile};
    my @size = $tile->size;
    return Geo::GDAL::Driver('MEM')->Create(Type => 'Byte', Width => $size[0], Height => $size[1]) unless $self->{mask};
    return $self->{mask}->Translate( 
        "/vsimem/tmp.tiff", 
        [ -ot => 'Byte', 
          -of => 'GTiff', 
          -r => 'nearest',
          -outsize => $tile->size,
          -projwin => $tile->projwin,
          -a_ullr => $tile->projwin
        ]) if $self->{epsg} == 3067;
    my $e = $tile->extent; 
    return $self->{mask}->Warp(
        "/vsimem/tmp.tiff", 
        [ -ot => 'Byte',
          -of => 'GTiff',
          -r => 'near',
          -t_srs => 'EPSG:'.$self->{epsg},
          -te => @$e,
          -ts => $tile->size
        ]);
}

1;
