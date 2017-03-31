package SmartSea::Schema::Result::Style;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use Encode qw(decode encode);
use Imager::Color;
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

my %attributes = (
    color_scale =>  { i => 1, input => 'lookup', class => 'ColorScale', allow_null => 0 },
    min =>          { i => 3, input => 'text', size => 20, empty_is_null => 1 },
    max =>          { i => 4, input => 'text', size => 20, empty_is_null => 1 },
    classes =>      { i => 5, input => 'text', size => 20, empty_is_null => 1 },
    class_labels => { i => 6, input => 'text', size => 40 }
    );

__PACKAGE__->table('styles');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(color_scale => 'SmartSea::Schema::Result::ColorScale');

sub attributes {
    return \%attributes;
}

sub order_by {
    return {-asc => 'color_scale'};
}

sub name {
    my $self = shift;
    my $name = '';
    $name .= $self->color_scale->name if $self->color_scale;
    $name .= ' ['.$self->min.'..'.$self->max.']' if defined $self->min && defined $self->max;
    $name .= ' '.$self->classes.' classes' if defined $self->classes;
    return $name;
}

sub inputs {
    my ($self, $values, $schema) = @_;
    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Style')) {
        for my $key (keys %attributes) {
            next unless defined $self->$key;
            next if defined $values->{$key};
            $values->{$key} = $self->$key;
        }
    }
    return widgets(\%attributes, $values, $schema);
}

sub prepare {
    my $self = shift;    
    my $n = $self->classes // 101;
    my $colors = Geo::GDAL::ColorTable->new();
    my $palette = $self->color_scale->name;
    #say STDERR "prepare ",$self->name;

    if ($n == 1) {

        $colors->Color(0, [0,0,0,0]);
        my $color;
        for ($palette) {
            if    (/inverse-grayscale/)  { $color = [127,127,127,255] }
            elsif (/red-to-green/)  { $color = [  0,255,  0,255] }
            elsif (/green-to-red/)  { $color = [255,  0,  0,255] }
            elsif (/water-depth/)   { $color = [ 44, 55,255,255] }
            elsif (/red/)           { $color = [255, 44, 44,255] }
            elsif (/green/)         { $color = [ 55,255, 44,255] }
            elsif (/blue/)          { $color = [ 44, 55,255,255] }
            elsif (/brown/)         { $color = [179,101,  0,255] }
            else                    { $color = [  0,  0,  0,255] }
        }
        $colors->Color(1, [0,0,0,255]);
        
    } elsif ($palette eq 'grayscale') { # black to white

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 0, 0, $c*$k ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'red-to-green') { # hue 0 -> 120

        my $k = 120/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ $c*$k, 1, 1 ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'green-to-red') { # hue 120 -> 0

        my $k = 120/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 120-$c*$k, 1, 1 ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'water-depth') { # hue 182 -> 237

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 182+(237-182)*$c*$k, 1, 1 ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'red') {

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                my ($s, $v) = (1,1);
                if ($c < $n/2) {
                    $s = 60+(100-60)*$c*$k;
                } else {
                    $v = 100-(60-100)*$c*$k;
                }
                hsv => [ 0, $s, $v ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'green') {

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 120, 1, 1 - 0.7*$c*$k ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'blue') {

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                my ($s, $v) = (1,1);
                if ($c < $n/2) {
                    $s = 60+(100-60)*$c*$k;
                } else {
                    $v = 100-(60-100)*$c*$k;
                }
                hsv => [ 240, $s, $v ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($palette eq 'brown') { # value 1 -> 0.3

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 34, 1, 1 - 0.7*$c*$k ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } else { # white to black

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 0, 0, 1-$c*$k ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    }

    $colors->Color(255, [0,0,0,0]);

    $self->{color_table} = $colors;
}

sub value_to_color {
    my ($self, $value) = @_;
    my $nc = $self->classes // 101;
    my $c;
    if ($nc == 1) {
        $c = $self->{color_table}->Color(1);
    } else {
        my $min = $self->min // 0;
        my $max = $self->max // 1;
        $max = $min + 1 if $max <= $min;
        my $class = int($nc*($value-$min)/($max-$min));
        --$class if $class > $nc-1;
        $c = $self->{color_table}->Color($class);
    }
    return @$c;
}

sub value_to_class {
    my ($self, $value) = @_;
}

sub class_to_value {
    my ($self, $class) = @_;
}

sub legend {
    my ($self, $args) = @_;
    
    my $min = $self->min // 0;
    my $max = $self->max // 1;
    my $unit = $args->{unit} // '';

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

    my $nc = $self->classes;
    
    unless (defined $nc) {
        $image->line($args->{symbology_width}+1, $half_font, $args->{symbology_width}+5, $half_font, $color);
        $image->stringFT(@string, $args->{font_size}, "$max$unit");
        my $y2 = $args->{height} - $half_font - 1;
        $image->line($args->{symbology_width}+1, $y2, $args->{symbology_width}+5, $y2, $color);
        $image->stringFT(@string, $args->{height}, "$min$unit");
    } else {
        my $step = int($nc/($symbology_height/($args->{font_size}+4))+0.5);
        $step = 1 if $step < 1;
        my $d = $self->class_labels // '';
        my $c = $nc == 1 ? 0 : ($max - $min) / $nc;
        my $current = 0;
        my $last = 0;
        for (my $class = 1; $class <= $nc; $class += $step) {
            # class to y
            my $y = $args->{height} - $half_font - int(($class-0.5)*$symbology_height/$nc);
            my $l;
            my ($l2) = $d =~ /$class = ([\w, \-]+)/;
            if ($nc == 1) {
                $l = $d;
            } elsif ($l2) {
                $l = encode utf8 => $l2;
            } elsif (defined $min) {
                $current = $min + $c*$class;
                if ($class == 1) {
                    $l = sprintf("<=%.1f", $current) . $unit;
                } elsif ($class+$step > $nc) {
                    $l = sprintf("> %.1f", $last) . $unit;
                } else {
                    $l = sprintf("(%.1f,%.1f]", $last, $current) . $unit;
                }
                $last = $current;
            } else {
                $l = $class;
            }
            #$image->line($args->{symbology_width}+1, $y, $args->{symbology_width}+5, $y, $color);
            $image->stringFT(@string, $y+$half_font, $l);
        }
    }
    return $image;
}

1;
