package SmartSea::Schema::Result::Style;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Carp;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use Encode qw(decode encode);
use Imager::Color;
use GD;
use Geo::GDAL;
use SmartSea::Core;
use SmartSea::HTML qw(:all);

# min..max is the range of data values that is mapped to colors
# values less than min are mapped to first color
# values greater than max are mapped to last color
# classes is the number of colors
#     NULL => continuous data (101 colors)
#     1    => class 1 = no color, class 2 = color
#     >=2  => classes colors
# colortable values are 
#     0..100 for continuous data
#     0..classes-1 for discrete data
#     255 for transparent

my @columns = (
    id           => {},
    color_scale =>  { is_foreign_key => 1, source => 'ColorScale', not_null => 1 },
    min =>          { data_type => 'double', html_size => 20 },
    max =>          { data_type => 'double', html_size => 20 },
    classes =>      { data_type => 'integer', html_size => 20 }
    # todo: add semantics here, which in dataset case gets its value from there primarily
    );

__PACKAGE__->table('styles');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(color_scale => 'SmartSea::Schema::Result::ColorScale');
__PACKAGE__->has_many(layer => 'SmartSea::Schema::Result::Layer', 'style'); # 0 or 1
__PACKAGE__->has_many(dataset => 'SmartSea::Schema::Result::Dataset', 'style'); # 0 or 1
__PACKAGE__->has_many(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent', 'style'); # 0 or 1

sub order_by {
    return {-asc => [qw/color_scale id/]};
}

sub name {
    my $self = shift;
    my $name = '';
    $name .= $self->color_scale->name // '' if $self->color_scale;
    $name .= ' ['.$self->min.'..'.$self->max.']' if defined $self->min && defined $self->max;
    $name .= ' '.$self->classes.' classes' if defined $self->classes;
    my @layer = $self->layer;
    $name .= " in ".$layer[0]->name if @layer;
    @layer = $self->ecosystem_component;
    $name .= " in ".$layer[0]->name if @layer;
    @layer = $self->dataset;
    $name .= " in ".$layer[0]->name if @layer;
    return $name;
}

sub prepare {
    my ($self, $args) = @_;

    if (defined $self->min) {
        if (defined $args->{min}) {
            $args->{bound} = $args->{min} < $self->min;
        }
    } else {
        $self->min($args->{min} // 0);
    }
    if (defined $self->max) {
        if (defined $args->{max}) {
            $args->{bound} = $args->{max} > $self->max;
        }
    } else {
        $self->max($args->{max} // 1);
    }

    unless (defined $self->classes) {
        if ($args->{data_type} && $args->{data_type} == 1) {
            $self->classes($self->max - $self->min + 1);
        } else {
            $self->classes(101);
            $args->{ticks} = 1;
            $args->{ranges} = 1;
        }
    }
    unless ($args->{ticks}) {
        if ($self->classes > 101) {
            $self->classes(101);
            $args->{ticks} = 1;
            $args->{ranges} = 1;
        }
    }
    $args->{ranges} = 1 if $args->{data_type} != 1;
}

sub legend {
    my ($self, $args) = @_;
    
    # $args->{data_type}; # 1 is int

    # legend is classed or ticked
    # if labels or limited range of ints -> classed
    # height is from classes
    for (qw/min max data_type/) {
        croak "legend: $_ not defined\n" unless defined $args->{$_};
    }

    $self->prepare($args);
    
    my $color_table = $args->{color_table} // $self->color_scale->color_table($self->classes);

    $args->{value_to_color} = sub {
        my $value = shift;
        return $color_table->Color(1) if $self->classes == 1;
        my $class = int($self->classes * ($value - $self->min)/($self->max - $self->min));
        $class = 0 if $class < 0;
        $class = $self->classes - 1 if $class >= $self->classes;
        return $color_table->Color($class);
    };

    #say STDERR $self->min.' .. '.$self->max.' '.($self->classes // '');

    $args->{width} //= 200;
    $args->{height} //= 140;
    $args->{unit} //= '';
    $args->{tick_width} //= 5;
    $args->{label_vertical_padding} //= 2;
    $args->{label_horizontal_padding} //= 5;
    $args->{max_labels} //= 30;

    $args->{class_height} = $args->{font_size} + 2 * $args->{label_vertical_padding};

    return $self->ticked_legend($args) if $args->{ticks};
    return $self->classed_legend($args);
    
}

sub ticked_legend {
    my ($self, $args) = @_;
    
    my $image = GD::Image->new($args->{width}, $args->{height});
    $image->filledRectangle(0,0,$args->{width}-1,$args->{height}-1,$image->colorAllocateAlpha(255,255,255,0));

    # color bar

    my $padding = $args->{font_size}/2 + $args->{label_vertical_padding};
    my $y1 = $args->{height} - 1 - $padding;
    my $y2 = $padding;
    my $k = ($self->max - $self->min) / ($y2 - $y1);
    for my $y ($y2 .. $y1) {
        my $value = $self->min + ($y - $y1) * $k;
        my $color = $image->colorAllocateAlpha($args->{value_to_color}($value));
        $image->line(0,$y,$args->{colorbar_width},$y,$color);
    }

    # ticks

    my $color = $image->colorAllocateAlpha(0,0,0,0);
    my $x = $args->{colorbar_width} + 1;
    for (my $y = $y1; $y > 0; $y -= $args->{class_height}) {
        my $yLine = $y;
        ++$yLine if $y < $y1;
        $image->line($x,$yLine,$x + $args->{tick_width},$yLine,$color);
    }
    
    # labels
    
    my @string = (
        $image->colorAllocateAlpha(0,0,0,0), 
        $args->{font}, 
        $args->{font_size}, 
        0, # angle
        $args->{colorbar_width} + $args->{tick_width} + $args->{label_horizontal_padding} # x
        );

    for (my $y = $y1; $y > 0; $y -= $args->{class_height}) {
        my $yLine = $y;
        ++$yLine if $y < $y1;
        my $value = $self->min + ($yLine - $y1) * $k;
        $value = sprintf("%.2f", $value);
        my $label = $value . ' ' . $args->{unit};
        $image->stringFT(@string, $yLine + $args->{font_size}/2, $label);
    }

    return $image;
}

sub classed_legend {
    my ($self, $args) = @_;
        
    my $height = int($args->{class_height} * $self->classes);

    my $image = GD::Image->new($args->{width}, $height);
    $image->filledRectangle(0,0,$args->{width}-1,$height-1,$image->colorAllocateAlpha(255,255,255,0));

    # color bar

    my $y1 = $height - 1;
    my $y2 = $y1 - $args->{class_height} + 1;
    my $k = ($self->max - $self->min) / $self->classes;
    for my $class (0..$self->classes-1) {
        my $value = $self->min + $class * $k;
        my $color = $image->colorAllocateAlpha($args->{value_to_color}($value));
        $image->filledRectangle(0,$y1,$args->{colorbar_width},$y2,$color);
        $y1 = $y2 + 1;
        $y2 -= $args->{class_height};
    }

    # labels
    
    my $labels = $args->{labels};

    my @string = (
        $image->colorAllocateAlpha(0,0,0,0), 
        $args->{font}, 
        $args->{font_size}, 
        0, # angle
        $args->{colorbar_width} + $args->{label_horizontal_padding} # x
        );

    my $y = $height - 1 - $args->{label_vertical_padding};
    $k = ($self->max - $self->min) / $self->classes;
    my $x = $self->min;
    for my $class (0..$self->classes-1) {
        my $value = $self->min + $class * $k;
        my $label;
        if ($labels) {
            $label = $labels->{$x};
            ++$x; # FIXME assuming continuous range! fixing would require changes to rendering
        } elsif ($args->{ranges}) {
            my $next = $self->min + ($class+1) * $k;
            if ($args->{bound}) {
                if ($class == 0) {
                    $label = "< $next $args->{unit}";
                } elsif ($class == $self->classes-1) {
                    $label = ">= $value $args->{unit}";
                } else {
                    $label = "($value..$next] $args->{unit}";
                }
            } else {
                if ($class == 0) {
                    $label = "[$value..$next] $args->{unit}";
                } else {
                    $label = "($value..$next] $args->{unit}";
                }
            }
        } else {
            $label = $value;
        }
        $image->stringFT(@string, $y, (encode utf8 => $label));
        $y -= $args->{class_height};
    }

    if ($args->{title}) {
        $x = $string[4] + $args->{label_width};
        $y = int(($height + $args->{font_size})/2); 
        $image->stringFT(@string[0..3], $x, $y, (encode utf8 => $args->{title}));
    }

    return $image;
}

1;
