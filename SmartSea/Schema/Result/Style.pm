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

# This is a mixture of a row and Geo::GDAL::ColorTable
#     call prepare to create the Geo::GDAL::ColorTable
#
# min..max is the range of data values that is mapped to colors
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
    min =>          { data_type => 'text', html_size => 20, empty_is_null => 1 },
    max =>          { data_type => 'text', html_size => 20, empty_is_null => 1 },
    classes =>      { data_type => 'text', html_size => 20, empty_is_null => 1 }
    # todo: add semantics here, which in dataset case gets its value from there primarily
    );

__PACKAGE__->table('styles');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(color_scale => 'SmartSea::Schema::Result::ColorScale');

sub order_by {
    return {-asc => 'color_scale'};
}

sub name {
    my $self = shift;
    my $name = '';
    $name .= $self->color_scale->name // '' if $self->color_scale;
    $name .= ' ['.$self->min.'..'.$self->max.']' if defined $self->min && defined $self->max;
    $name .= ' '.$self->classes.' classes' if defined $self->classes;
    return $name;
}

sub prepare {
    my ($self, $args) = @_;
    #say STDERR "prepare style ",$self->id;
    # calls below will not update db unless insert or update is called
    $self->min($args->{min} // 0) unless defined $self->min;
    $self->max($args->{max} // 1) unless defined $self->max;
    $self->max($self->min) if $self->min > $self->max;
    unless (defined $self->classes) {
        my $n;
        if ($args->{data_type} == 1 && ($args->{max} - $args->{min} + 1) < 100) {
            $n = $args->{max} - $args->{min} + 1;
        } else {
            $n = 101;
        }
        #say STDERR "classes = ",$n;
        $self->classes($n);
    }
    $self->{color_table} = $self->color_scale->color_table($self->classes);
}

sub value_to_color {
    my ($self, $value) = @_;
    my $n = $self->classes;
    return $self->{color_table}->Color(1) if $n == 1;
    my $class = int($n * ($value - $self->min)/($self->max - $self->min));
    --$class if $class > $n-1;
    return $self->{color_table}->Color($class);
}

sub legend {
    my ($self, $args) = @_;
    
    # $args->{data_type}; # 1 is int

    # legend is classed or ticked
    # if labels or limited range of ints -> classed
    # height is from classes

    $args->{width} //= 200;
    $args->{height} //= 140;
    $args->{unit} //= '';
    $args->{tick_width} //= 5;
    $args->{label_vertical_padding} //= 2;
    $args->{label_horizontal_padding} //= 5;
    $args->{max_labels} //= 30;

    $args->{class_height} = $args->{font_size} + 2 * $args->{label_vertical_padding};

    if ($args->{data_type} != 1 || $self->max - $self->min > $args->{max_labels}) {
        return $self->ticked_legend($args);
    } else {
        return $self->classed_legend($args);
    }
    
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
        my $color = $image->colorAllocateAlpha($self->value_to_color($value));
        $image->line(0,$y,$args->{colorbar_width},$y,$color);
    }

    # ticks

    my $color = $image->colorAllocateAlpha(0,0,0,0);
    my $x = $args->{colorbar_width} + 1;
    for (my $y = $y1; $y > 0; $y -= $args->{class_height}) {
        my $yl = $y;
        ++$yl if $y < $y1;
        $image->line($x,$yl,$x + $args->{tick_width},$yl,$color);
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
        my $yl = $y;
        ++$yl if $y < $y1;
        my $value = $self->min + ($yl - $y1) * $k;
        my $label = $value . ' ' . $args->{unit};
        $image->stringFT(@string, $yl + $args->{font_size}/2, $label);
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
    for my $value ($self->min..$self->max) {
        my $color = $image->colorAllocateAlpha($self->value_to_color($value));
        $image->filledRectangle(0,$y1,$args->{colorbar_width},$y2,$color);
        $y1 = $y2 + 1;
        $y2 -= $args->{class_height};
    }

    # labels
    
    my $labels = $args->{labels} // {};

    my @string = (
        $image->colorAllocateAlpha(0,0,0,0), 
        $args->{font}, 
        $args->{font_size}, 
        0, # angle
        $args->{colorbar_width} + $args->{label_horizontal_padding} # x
        );

    my $y = $height - 1 - $args->{label_vertical_padding};
    for my $value ($self->min..$self->max) {
        my $label = $labels->{$value} // $value;
        $image->stringFT(@string, $y, (encode utf8 => $label));
        $y -= $args->{class_height};
    }

    return $image;
}

1;
