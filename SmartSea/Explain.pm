package SmartSea::Explain;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;

use SmartSea::Core;

use parent qw/Plack::Component/;

binmode STDERR, ":utf8"; 

sub new {
    my ($class, $self) = @_;
    $self = Plack::Component->new($self);
    $self->{sea} = Geo::GDAL::Open("$self->{config}{data_path}/sum.tiff");
    $self->{depth} = Geo::GDAL::Open("$self->{config}{data_path}/depth-classes.tiff");
    $self->{natura} = Geo::GDAL::Open("$self->{config}{data_path}/natura.tiff");
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    my $ret = common_responses($env);
    return $ret if $ret;
    my $request = Plack::Request->new($env);
    my $parameters = $request->parameters;
    for my $key (sort keys %$parameters) {
        my $val = $parameters->{$key} // '';
        say STDERR "$key => $val";
    }
    my @layers = $request->query_parameters->get_all('layer');
    say STDERR "layers = @layers";
    my @layer_names = @layers;
    for (@layer_names) {
        s/_/ /g;
        s/^(\w)/uc($1)/e;
        s/ (\w+)$/, $1<br \/>&nbsp;&nbsp;bla bla<br \/>/;
    }

    my $gt = $self->{sea}->GeoTransform;
    my $report = "@layer_names<br />";

    if (@layers == 0) {

        $report = 'No selected layers';

    } elsif ($parameters->{wkt}) {
        my ($canvas, $extent, $overview, $cell_area, @clip) = canvas($gt, $parameters->{wkt});
        
        my $a = $canvas->Band()->Piddle();
        my $A = sum($a);
        say STDERR "cells in polygon $A";

        $report .= '(from overview) ' if $overview;
        my $s;
        eval {
            $s = $self->{depth}->Band()->Piddle(@clip);
        };
        unless ($@) {
            $s = $a*($s+1); # adjust land cover values to 1..4
            my @lc;
            for my $i (0..3) {
                my $result = $a*0;
                my $x = $result->where($s == ($i+1));
                $x .= 1;
                $lc[$i] = int(sum($result)/$A*100);
            }
            $report .= "land " . $lc[0] . '%' .
                ', shallow ' . $lc[1] . '%' .
                ', trans ' . $lc[2] . '%' .
                ', deep ' . $lc[3] . '%';
        } else {
            $report .= 'no data';
        }
        $report .= ", total " . int($A*$cell_area+0.5) . " km2";
        say STDERR $report;

    } else {

        my @c = $gt->Inv->Apply([$parameters->{easting}],[$parameters->{northing}]);
        my $x = int($c[0]->[0]);
        my $y = int($c[1]->[0]);
        my $d = 0;
        my $n = 0;
        eval {
            $d = $self->{depth}->Band(1)->ReadTile($x, $y, 1, 1)->[0][0];
            $n = $self->{natura}->Band(1)->ReadTile($x, $y, 1, 1)->[0][0];
        };
        say STDERR "depth = $d";
        say STDERR "natura = $n";

        my %d = (1 => 'Shallow', 2 => 'Transitional', 3 => 'Deep');

        $report .= decode(utf8 => $d{$d} // 'No data') . ' ' . $n;

    }

    return json200({report => $report});

}

sub canvas {
    my ($gt, $wkt) = @_;
    my $g = Geo::OGR::Geometry->new(WKT => $wkt);
    my $e = $g->Extent;
    my $inv = $gt->Inv;
    my ($l_col, $u_row) = $inv->Apply($e->[0], $e->[3]);
    $l_col = int($l_col);
    $u_row = int($u_row);
    my ($r_col, $d_row) = $inv->Apply($e->[1], $e->[2]);
    $r_col = int($r_col)+1;
    $d_row = int($d_row)+1;
    my $w = $r_col - $l_col;
    my $h = $d_row - $u_row;
    
    my $W = $w;
    my $H = $h;
    my $d = 1;
    
    # if w x h is too large then read an overview
    while ($W * $H > 1000000) {
        $d *= 2;
        $W /= 2;
        $H /= 2;
    }
    $W = int($W);
    $H = int($H);
    
    # create a canvas for drawing the geometry
    my $canvas = Geo::GDAL::Driver('MEM')->Create(Width => $W, Height => $H);
    my ($ulx, $uly) = $gt->Apply($l_col, $u_row);
    my $gtx = $gt->[1]*($w/$W); # assuming north up
    my $gty = $gt->[5]*($h/$H); # assuming north up
    $canvas->GeoTransform($ulx, $gtx, 0, $uly, 0, $gty);
    my $cell_area = abs($gtx * $gty)/1000000.0; # km2
    say STDERR "cell area $cell_area";

    # create a layer, which to draw on the canvas
    my $wkt_ds = Geo::OGR::Driver('Memory')->Create('wkt');
    $wkt_ds->CreateLayer( Name => 'wkt',
                          Fields => [{
                              Name => 'geom',
                              Type => 'Polygon' }] )
        ->InsertFeature({geom => $g});
    
    $wkt_ds->Rasterize($canvas, { l => 'wkt', burn => 1 });

    return ($canvas, $e, $d > 1, $cell_area, $l_col, $u_row, $w, $h, $W, $H);
}

1;
