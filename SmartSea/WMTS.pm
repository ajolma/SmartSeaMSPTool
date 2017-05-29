package SmartSea::WMTS;
use utf8;
use strict;
use warnings;
use 5.010000;
use Carp;
use Encode qw(decode encode);
use JSON;
use DBI;
use Imager::Color;
use Geo::GDAL;
use PDL;
use PDL::NiceSlice;
use Geo::OGC::Service;
use Data::Dumper;

use SmartSea::Core qw(:all);
use SmartSea::Schema;
use SmartSea::Layer;

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    
    my $dsn = "PG:dbname='$self->{dbname}' host='localhost' port='5432'";
    $self->{GDALVectorDataset} = Geo::GDAL::Open(
        Name => "$dsn user=$self->{db_user} password=$self->{db_passwd}",
        Type => 'Vector');

    $self->{Suomi} = Geo::GDAL::Open(
        Name => "Pg:dbname=suomi user='ajolma' password='ajolma'", # fixme remove user here
        Type => 'Vector');

    return bless $self, $class;
}

sub config {
    my ($self, $config) = @_;
    #print STDERR Dumper $config;

    # QGIS asks for capabilities and does not load unadvertised layers
    
    my @tilesets;
    for my $plan ($self->{schema}->resultset('Plan')->all()) {
        my @uses;
        for my $use ($plan->uses) {
            my @layers;
            for my $layer ($use->layers) {
                push @tilesets, {
                    Layers => $plan->id."_".$use->use_class->id."_".$layer->layer_class->id,
                    'Format' => 'image/png',
                    Resolutions => '9..19',
                    SRS => "EPSG:3067",
                    BoundingBox => $config->{BoundingBox3067},
                    file => $self->{data_dir}."mask.tiff",
                    ext => "png"
                };
            }
        }
    }
    for my $dataset ($self->{schema}->resultset('Dataset')->layers) {
        push @tilesets, {
            Layers => "0_0_".$dataset->{id},
            "Format" => "image/png",
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => $self->{data_dir}."mask.tiff",
            ext => "png"
        };
    }
    for my $component ($self->{schema}->resultset('EcosystemComponent')->layers) {
        push @tilesets, {
            Layers => "1_1_".$component->{id},
            "Format" => "image/png",
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => $self->{data_dir}."mask.tiff",
            ext => "png"
        };
    }

    for my $protocol (qw/TMS WMS WMTS/) {
        $config->{$protocol}->{TileSets} = \@tilesets;
        $config->{$protocol}->{serve_arbitrary_layers} = 1;
        $config->{$protocol}->{layer} = {'no-cache' => 1};
    }

    return $config;
}

sub process {
    my ($self, $dataset, $tile, $server) = @_;
    #print STDERR Dumper $server->{env};
    my $params = $server->{parameters};

    # WMTS clients ask for layer and specify tilematrixset
    # WMS clients ask for layers and specify srs
    my $epsg;
    if ($params->{tilematrixset}) {
        if ($params->{tilematrixset} eq 'ETRS-TM35FIN') {
            $epsg = 3067;
        } else {
            ($epsg) = $params->{tilematrixset} =~ /EPSG:(\d+)/;
        }
    } elsif ($params->{srs}) {
        ($epsg) = $params->{srs} =~ /EPSG:(\d+)/;
    }

    my $debug = $params->{debug};

    my @t = $tile->tile;
    my @pw = $tile->projwin;
    
    my $want = $params->{layer} // $params->{layers};
    # $server->{env}->{REMOTE_ADDR};
    say STDERR "$server->{service}&request=$params->{request}&crs=EPSG:$epsg&layer=$want";

    # the client asks for plan_use_layer_rule_rule_...
    # rules are those rules that the client wishes to be active
    # no rules = all rules?

    my $layer = SmartSea::Layer->new({
        epsg => $epsg,
        tile => $tile,
        schema => $self->{schema},
        data_dir => $self->{data_dir},
        GDALVectorDataset => $self->{GDALVectorDataset},
        cookie => $server->{request}->cookies->{SmartSea} // DEFAULT, 
        trail => $want,
        style => $params->{style} });

    unless ($epsg && $layer->{duck}) {
        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->Create(
            Name => "/vsimem/r.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>$epsg));
        say STDERR "NO EPSG!";
        return $ds;
    }
    
    if ($want eq 'suomi') {

        #for my $key (sort keys %$params) {
        #    say STDERR "$key $params->{$key}";
        #}
        
        # use $params->{style} ?

        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->
            Create(Name => "/vsimem/suomi.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;

        my $scale = ($maxx-$minx)/256; # m/pixel
        my $tolerance;
        for my $x (1000,100,50) {
            if ($scale > $x) {
                $tolerance = $x;
            }
        }
        $tolerance //= '';
        my $layer = 'maat'.$tolerance;

        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>3067));
        #$ds->Band(1)->ColorTable($self->{palette}{suomi});
        $self->{Suomi}->Rasterize($ds, [-burn => 1, -l => 'f_l1_3067']);
        $self->{Suomi}->Rasterize($ds, [-burn => 2, -l => $layer]);
        $self->{Suomi}->Rasterize($ds, [-burn => 3, -l => 'maakunnat_rajat']);
        $self->{Suomi}->Rasterize($ds, [-burn => 3, -l => 'eez_rajat']);

        #say STDERR $want;

        # Cache-Control should be only max-age=seconds something
        return $ds;
    }

    unless ($layer->{duck}) {
        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->
            Create(Name => "/vsimem/suomi.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>3067));
        say STDERR "no layer";
        return $ds;
    }

    my $result = $layer->compute($debug);

    # if $layer is in fact a dataset
    # Cache-Control should be only max-age=seconds something

    # else
    # Cache-Control must be 'no-cache, no-store, must-revalidate'
    # since layer may change
    return $result;
}

sub count {
    my ($x, $val, @size) = @_;
    my $ones = zeroes(@size);
    $ones->where($x == $val) .= 1;
    return $ones->sum;
}

1;
