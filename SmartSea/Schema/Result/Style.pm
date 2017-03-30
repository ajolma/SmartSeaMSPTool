package SmartSea::Schema::Result::Style;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
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

    if ($palette eq 'inverse-grayscale') { # white to black

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 0, 0, 1-$c*$k ]
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
        
    } elsif ($palette eq 'green') {

        $self->{classes} = 1;
        $colors->Color(0, [0,255,0,255]);

    } elsif ($palette eq 'black') {

        $self->{classes} = 1;
        $colors->Color(0, [0,0,0,255]);
        
    } elsif ($palette eq 'browns') { # value 1 -> 0.3

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 34, 1, 1 - 0.7*$c*$k ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    } else { # black to white
        $palette = 'grayscale';

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 0, 0, $c*$k ]
            );
            $colors->Color($c, [$hsv->rgba]);
        }
        
    }

    $colors->Color(255, [0,0,0,0]);

    $self->{color_table} = $colors;
}

sub color {
    my ($self, $index) = @_;
    my $c = $self->{color_table}->Color($index);
    return @$c;
}

sub value_to_color {
    my ($self, $value) = @_;
}

sub value_to_class {
    my ($self, $value) = @_;
}

sub class_to_value {
    my ($self, $class) = @_;
}

1;
