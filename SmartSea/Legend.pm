package SmartSea::Legend;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use SmartSea::Core qw(:all);
use SmartSea::Layer;

use parent qw/Plack::Component/;

sub new {
    my ($class, $self) = @_;
    $self = Plack::Component->new($self);
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    my $ret = common_responses({}, $env);
    return $ret if $ret;
    my $request = Plack::Request->new($env);
    my $parameters = $request->parameters;
    
    my $layer;
    eval {
        $layer = SmartSea::Layer->new({
            schema => $self->{schema},
            cookie => DEFAULT,
            trail => $parameters->{layer}});
    };
    print STDERR "$@";
        
    my $image = $layer ?
        $layer->{style}->legend({
            unit => $layer->unit,
            font => '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            font_size => 10,
            width => 200, # layout.css.right.width
            height => 140,
            symbology_width => 50}) 
        :
        GD::Image->new('/usr/share/icons/cab_view.png');

    return [ 200, 
             ['Content-Type' => 'image/png', 'Access-Control-Allow-Origin' => '*'], 
             [$image->png] ];

}

1;
