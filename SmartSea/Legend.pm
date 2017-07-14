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
    my $style;
    $style = $parameters->{style} if $parameters->{style};
    eval {
        $layer = SmartSea::Layer->new({
            debug => $parameters->{debug},
            schema => $self->{schema},
            style => $style,
            trail => $parameters->{layer}});
    };
    print STDERR "$@";
        
    my $image = $layer ?
        $layer->legend({
            font => '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            font_size => 10,
            width => 200, # layout.css.right.width
            height => 140,
            colorbar_width => 50}) 
        :
        GD::Image->new('/usr/share/icons/cab_view.png');

    return [ 200, 
             ['Content-Type' => 'image/png', 'Access-Control-Allow-Origin' => '*'], 
             [$image->png] ];

}

1;
