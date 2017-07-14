package SmartSea::Explain;
use parent qw/SmartSea::App/;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core qw(:all);

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    $self = SmartSea::App->new($self);
    $self->{mask} = Geo::GDAL::Open($self->{data_dir}.'mask.tiff');
    return bless $self, $class;
}

sub smart {
    my ($self, $env, $request, $parameters) = @_;
    
    for my $key (sort keys %$parameters) {
        my $val = $parameters->{$key} // '';
        #say STDERR "$key => $val";
    }
    
    # default is that of data, EPSG:3067, if not it is in srs
    my $srs = $parameters->{srs} // $parameters->{SRS};
    ($srs) = $srs =~ /(\d+)/ if $srs;

    my $ct;
    if ($srs && $srs != 3067) {
        my $src = Geo::OSR::SpatialReference->new(EPSG => $srs);
        my $dst = Geo::OSR::SpatialReference->new(EPSG => 3067);
        $ct = Geo::OSR::CoordinateTransformation->new($src, $dst);
    }
    
    #my @rules;
    #for my $layer ($request->query_parameters->get_all('layer')) {
    #    push @rules, SmartSea::Layer->new({schema => $self->{schema}, trail => $layer});
    #}
    my $plan_id = $request->query_parameters->get('plan');
    my $use_id = $request->query_parameters->get('use');
    my $layer_id = $request->query_parameters->get('layer');
    say STDERR "plan = $plan_id, use = ",($use_id//'undef'),", layer = ",($layer_id//'undef');
    my $dataset;
    if (defined $use_id && $use_id == 0) {
        $dataset = $self->{schema}->resultset('Dataset')->single({id => $layer_id});
        say STDERR $dataset->path;
    }
    
    my $report = '';

    if ($parameters->{wkt}) {

        my $polygon = Geo::OGR::Geometry->new(WKT => $parameters->{wkt});
        $polygon->Transform($ct) if $ct;
        say STDERR "polygon = ",$polygon->As(Format => 'WKT') if $self->{debug};
        eval {
            $report = $self->make_polygon_report($polygon);
        };
        if ($@) {
            my @e = split /\n/, $@;
            say STDERR $e[0];
            $report = 'Bad request (probably self-intersecting polygon).';
        }

    } elsif ($parameters->{easting} && $parameters->{northing}) {

        my $point = [$parameters->{easting},$parameters->{northing}];
        $point = $ct->TransformPoint(@$point) if $ct;
        say STDERR "location = @$point" if $self->{debug};
        $report = $self->make_point_report($point, $dataset);

    } else {
        
        $report = 'Bad request.';
        
    }

    return $self->json200({report => $report});

}

sub make_point_report {
    my ($self, $point, $dataset) = @_;

    for my $key (sort keys %{$self->{schema}{storage}}) {
        #say STDERR "$key => $self->{schema}{storage}{$key}" if $self->{debug};
    }

    if ($dataset && $dataset->id == 110) {
        my $table = $dataset->path;
        $table =~ s/^PG://;
        $table =~ s/\./"."/g;
        my $sql = 
            "select * from \"$table\" ".
            "where st_within(st_geomfromtext('POINT(@$point)',3067),geom)";
        my $result = $self->{schema}{storage}{_dbh}->selectall_hashref($sql, 'gid');
        my $html = '';
        for my $gid (sort {$a <=> $b} keys %$result) {
            $html .= "<i>gid</i>: $gid<br />";
            for my $key (sort keys %{$result->{$gid}}) {
                next if $key eq 'gid';
                next if $key eq 'geom';
                $html .= "&nbsp;&nbsp;<i>$key</i>: $result->{$gid}{$key}<br />";
            }
        }
        return $html;
    }

    if ($dataset && $dataset->id == 78) {
        my $table = decode utf8 => 'natura_hiekkasärkkä_ja_riutta_alle_20m';
        my $sql = 
            "select naturatunn from vesiviljely.\"$table\"".
            "where st_within(st_geomfromtext('POINT(@$point)',3067),geom)";
        my $result = $self->{schema}{storage}{_dbh}->selectall_arrayref($sql);
        if ($result->[0][0]) {
            my $url = 'http://natura2000.eea.europa.eu/Natura2000/SDF.aspx';
            return "<a target=\"_blank\" href=\"$url?site=$result->[0][0]\">$result->[0][0]</a>";
        }
    }
    
    my $gt = $self->{mask}->GeoTransform;
    my @c = $gt->Inv->Apply([$point->[0]],[$point->[1]]);
    my $x = int($c[0]->[0]);
    my $y = int($c[1]->[0]);
    my $d = 0;
    my $n = 0;
    eval {
        $d = $self->{mask}->Band(1)->ReadTile($x, $y, 1, 1)->[0][0];
    };
    my %d = (0 => 'Outside of region', 1 => 'Inside of region');
    my $report;
    $report .= $d{$d};
    return $report;
}

sub make_polygon_report {
    my ($self, $polygon) = @_;
    
    my $e = $self->{mask}->Extent;
    my @points = ([$e->[0],$e->[1]], [$e->[0],$e->[3]], [$e->[2],$e->[3]], [$e->[2],$e->[1]]);
    push @points, $points[0];
        
    my $region = Geo::OGR::Geometry->new(GeometryType => 'Polygon', Points => [[@points]]);

    my $gt = $self->{mask}->GeoTransform;
    my ($canvas, $extent, $overview, $cell_area, @clip) = canvas($gt, $polygon, $region);
        
    my $p = $canvas->Band()->Piddle();
    my $s = $self->{mask}->Band()->Piddle(@clip);
    my $A = sum($p * $s); # cells in polygon

    my $report = '';

    $report .= 'Following are estimates.<br />' if $overview;
    $report .= "Sea area in the selection: " . int($A*$cell_area+0.5) . " km2";
        
    # the idea here would be to compute average values and/or amount of allocated areas
    # in the polygon area
    if (0) {
        my $s;
        eval {
            $s = $self->{mask}->Band()->Piddle(@clip);
        };
        unless ($@) {
            $s = $p*($s+1); # adjust land cover values to 1..4
            my @lc;
            for my $i (0..3) {
                my $result = $p*0;
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
    }
    return $report;
}

sub canvas {
    my ($gt, $polygon, $region) = @_;
    my $g = $polygon->Intersection($region);
    my $e = $g->Extent;
    my $inv = $gt->Inv;
    my ($l_col, $u_row) = $inv->Apply($e->[0], $e->[3]);
    $l_col = int($l_col);
    $u_row = int($u_row);
    my ($r_col, $d_row) = $inv->Apply($e->[1], $e->[2]);
    $r_col = int($r_col);
    $d_row = int($d_row);
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
    my $cell_area = abs($gtx * $gty)/1000000.0; # km2, EPSG 3067 coordinates are in meters

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
