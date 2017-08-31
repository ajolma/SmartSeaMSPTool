package SmartSea::Legend;
use parent qw/SmartSea::App/;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use SmartSea::Core qw(:all);
use SmartSea::Layer;

sub smart {
    my ($self, $env, $request, $parameters) = @_;
    
    my $layer;
    my @style;
    # todo: set the style as palette, min, max
    eval {
        $layer = SmartSea::Layer->new({
            debug => $parameters->{debug},
            schema => $self->{schema},
            trail => $parameters->{layer}});
    };
    print STDERR "$@";

    my $image;
    
    if ($layer && $layer->style && $layer->style->palette) {

        my %args = (
            font => '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            font_size => 10,
            width => 200, # layout.css.right.width
            height => 140,
            colorbar_width => 50,
            );
        $args{top_to_bottom} = 1 if $layer->style->palette->name eq 'water-depth';
        
        $image = $layer->legend(\%args);

    } else {

        $image = GD::Image->new('/usr/share/icons/cab_view.png');

    }

    return [ 200, 
             ['Content-Type' => 'image/png', 'Access-Control-Allow-Origin' => '*'], 
             [$image->png] ];

}

1;
