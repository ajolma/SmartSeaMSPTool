package SmartSea::Palette;
use utf8;
use strict;
use warnings;
use 5.010000;
use Carp;
use Encode qw(decode encode);
use JSON;
use Imager::Color;

binmode STDERR, ":utf8";

# colortable values are 
#     0..100 for continuous data
#     0..classes-1 for discrete data
#     255 for transparent

sub new {
    my ($class, $self) = @_; # known arguments: color_scale, classes (>=1)

    $self = {} unless $self;
    if (defined $self->{classes}) {
        $self->{classes} = int($self->{classes});
        $self->{classes} = 2 if $self->{classes} < 2;
    } else {
        $self->{classes} = 101;
    }
    
    $self->{color_table} = Geo::GDAL::ColorTable->new();
    my $n = $self->{classes};
        
    if ($self->{color_scale} eq 'inverse_grayscale') { # white to black

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 0, 0, 1-$c*$k ]
            );
            $self->{color_table}->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($self->{color_scale} eq 'red_to_green') { # hue 0 -> 120

        my $k = 120/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ $c*$k, 1, 1 ]
            );
            $self->{color_table}->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($self->{color_scale} eq 'green_to_red') { # hue 120 -> 0

        my $k = 120/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 120-$c*$k, 1, 1 ]
            );
            $self->{color_table}->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($self->{color_scale} eq 'water_depth') { # hue 182 -> 237

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 182+(237-182)*$c*$k, 1, 1 ]
            );
            $self->{color_table}->Color($c, [$hsv->rgba]);
        }
        
    } elsif ($self->{color_scale} eq 'green') {

        $self->{classes} = 1;
        $self->{color_table}->Color(0, [0,255,0,255]);

    } elsif ($self->{color_scale} eq 'black') {

        $self->{classes} = 1;
        $self->{color_table}->Color(0, [0,0,0,255]);
        
    } elsif ($self->{color_scale} eq 'browns') { # value 1 -> 0.3

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 34, 1, 1 - 0.7*$c*$k ]
            );
            $self->{color_table}->Color($c, [$hsv->rgba]);
        }
        
    } else { # black to white
        $self->{color_scale} = 'grayscale';

        my $k = 1/($n-1);

        for my $c (0..$n-1) {
            my $hsv = Imager::Color->new(
                hsv => [ 0, 0, $c*$k ]
            );
            $self->{color_table}->Color($c, [$hsv->rgba]);
        }
        
    }

    $self->{color_table}->Color(255, [0,0,0,0]);

    return bless $self, $class;
}

sub is_discrete { # if not then is_continuous
    my $self = shift;
}

sub classes {
    my $self = shift;
    return $self->{classes};
}

sub color {
    my ($self, $index) = @_;
    my $c = $self->{color_table}->Color($index);
    return @$c;
}

sub color_table { # return Geo::GDAL::ColorTable
    my $self = shift;
    return $self->{color_table};
}
