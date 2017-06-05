package SmartSea::Schema::Result::Style;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
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
# class_labels should have the format "1 = class 1 label; 2 = class 2 label; ..."
# colortable values are 
#     0..100 for continuous data
#     0..classes-1 for discrete data
#     255 for transparent

my @columns = (
    id           => {},
    color_scale =>  { is_foreign_key => 1, source => 'ColorScale', allow_null => 0, required => 1 },
    min =>          { data_type => 'text', html_size => 20, empty_is_null => 1 },
    max =>          { data_type => 'text', html_size => 20, empty_is_null => 1 },
    classes =>      { data_type => 'text', html_size => 20, empty_is_null => 1 }
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
    # calls below will not update db unless insert or update is called
    $self->min($args->{min} // 0) unless defined $self->min;
    $self->max($args->{max} // 1) unless defined $self->max;
    $self->max($self->min + 1) if $self->max <= $self->min;
    $self->classes($args->{classes} // 101) unless defined $self->classes;
    $self->{color_table} = $self->color_scale->color_table($self->classes);
}

sub value_to_color {
    my ($self, $value) = @_;
    my $n = $self->classes;
    return $self->{color_table}->Color(1) if $n == 1;
    my $min = $self->min;
    my $max = $self->max;
    my $class = int($n*($value-$min)/($max-$min));
    --$class if $class > $n-1;
    return $self->{color_table}->Color($class);
}

sub legend {
    my ($self, $args) = @_;
    
    my $min = $self->min;
    my $max = $self->max;
    my $n = $self->classes;
    my $unit = $args->{unit};

    my $half_font = $args->{font_size}/2;
    my $symbology_height = $args->{height}-$args->{font_size};
    
    my $image = GD::Image->new($args->{width}, $args->{height});
    
    my $color = $image->colorAllocateAlpha(255,255,255,0);
    $image->filledRectangle($args->{symbology_width},0,99,$args->{height}-1+$args->{font_size},$color);
    for my $y (0..$half_font-1) {
        $image->line(0, $y, $args->{symbology_width}-1, $y, $color);
        my $y2 = $args->{height} - $half_font + $y;
        $image->line(0, $y2, $args->{symbology_width}-1, $y2, $color);
    }

    for my $h (0..$symbology_height-1) {
        my $y = $min + ($symbology_height-1-$h)*($max-$min)/($symbology_height-1);
        my $color = $image->colorAllocateAlpha($self->value_to_color($y));
        my $yl = $half_font+$h;
        $image->line(0, $yl, $args->{symbology_width}-1, $yl, $color);
    }
    
    $color = $image->colorAllocateAlpha(0,0,0,0);
    
    my @string = ($color, $args->{font}, $args->{font_size}, 0, $args->{symbology_width}+7);

    # how many labels fit in max?
    my $max_labels = int($symbology_height/($args->{font_size}+2));
        
    # classes per label
    my $classes_per_label = int($n/$max_labels);
    $classes_per_label = 1 if $classes_per_label < 1;
    
    # first class to have a label
    my $first_class_to_have_label = int($classes_per_label / 2);
    $first_class_to_have_label = 1 if $first_class_to_have_label < 1;
    
    # labels
    my @labels;
    
    if ($args->{labels}) {
        my $labels = encode utf8 => $args->{labels};
        @labels = split /\s*;\s*/, $labels;
        for (@labels) {
            s/^\s*\d+\s*=\s*//;
        }
    } else {
        my $x = $min;
        my $step = ($max - $min) / $n;
        $x += $step;
        push @labels, sprintf("<= %.1f", $x) . $unit;
        my $low = $min;
        for my $class (2..$n-1) {
            push @labels, sprintf("(%.1f,%.1f]", $low, $x) . $unit;
            $low = $x;
            $x += $step;
        }
        push @labels, sprintf("> %.1f", $x) . $unit;
    }
    
    for (my $class = $first_class_to_have_label; $class <= $n; $class += $classes_per_label) {
        my $y = $args->{height} - int(($class-0.5)*$symbology_height/$n) - 1;
        $image->stringFT(@string, $y, $labels[$class-1] // '');
    }

    return $image;
}

1;
