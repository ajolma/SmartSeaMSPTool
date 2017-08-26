package SmartSea::Schema::Result::Palette;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Geo::GDAL;

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1}
    );

__PACKAGE__->table('palettes');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');

sub color_table {
    my ($self, $n) = @_;

    my $palette = $self->name;
    
    my $colors = Geo::GDAL::ColorTable->new();
    
    if ($n == 1) {

        my $color;
        for ($palette) {
            if    (/inverse-grayscale/)  { $color = [127,127,127,255] }
            elsif (/red-to-green/)  { $color = [  0,255,  0,255] }
            elsif (/green-to-red/)  { $color = [255,  0,  0,255] }
            elsif (/water-depth/)   { $color = [ 44, 55,255,255] }
            elsif (/red/)           { $color = [180,  0,  0,255] }
            elsif (/green/)         { $color = [ 0, 135,  0,255] } # 120, 100, 53
            elsif (/blue/)          { $color = [ 0,   0,255,255] }
            elsif (/brown/)         { $color = [179,101,  0,255] }
            else                    { $color = [  0,  0,  0,255] }
        }
        $colors->Color(0, [0,0,0,0]);
        $colors->Color(1, $color);
        
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
            my ($s, $v) = (1,1);
            if ($c < $n/2) {
                $s = 60+(100-60)*$c*$k;
            } else {
                $v = 100-(60-100)*$c*$k;
            }
            my $hsv = Imager::Color->new(
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
            my ($s, $v) = (1,1);
            if ($c < $n/2) {
                $s = 60+(100-60)*$c*$k;
            } else {
                $v = 100-(60-100)*$c*$k;
            }
            my $hsv = Imager::Color->new(
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

    return $colors;
}

1;
