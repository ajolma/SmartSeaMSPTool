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

use SmartSea::Core qw(:all);
use SmartSea::Schema;
use SmartSea::Rules;
use SmartSea::Palette;

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    my $dsn = "dbi:Pg:dbname=$self->{dbname}";
    #$self->{dbh} = DBI->connect($dsn, $self->{user}, $self->{pass}, {});
    $self->{schema} = SmartSea::Schema->connect($dsn, $self->{user}, $self->{pass}, {});
    $dsn = "PG:dbname='$self->{dbname}' host='localhost' port='5432'";
    $self->{GDALVectorDataset} = Geo::GDAL::Open(
        Name => "$dsn user='$self->{user}' password='$self->{pass}'",
        Type => 'Vector');

    $self->{Suomi} = Geo::GDAL::Open(
        Name => "Pg:dbname=suomi user='ajolma' password='ajolma'", # fixme remove user here
        Type => 'Vector');

    return bless $self, $class;
}

sub config {
    my ($self, $config) = @_;

    # QGIS asks for capabilities and does not load unadvertised layers
    
    my @tilesets;
    for my $plan ($self->{schema}->resultset('Plan')->all()) {
        my @uses;
        for my $use ($plan->uses) {
            my $plan2use = $self->{schema}->
                resultset('Plan2Use')->
                single({plan => $plan->id, use => $use->id});
            my @layers;
            for my $layer ($plan2use->layers) {
                my $pul = $self->{schema}->
                    resultset('Plan2Use2Layer')->
                    single({plan2use => $plan2use->id, layer => $layer->id});
                push @tilesets, {
                    Layers => $plan->id."_".$use->id."_".$layer->id,
                    'Format' => 'image/png',
                    Resolutions => '9..19',
                    SRS => "EPSG:3067",
                    BoundingBox => $config->{BoundingBox3067},
                    file => "/home/ajolma/data/SmartSea/mask.tiff", # fixme wrong path
                    ext => "png"
                };
            }
        }
        for my $dataset ($self->{schema}->resultset('Dataset')->all) {
            next unless $dataset->path;
            push @tilesets, {
                Layers => "0_0_".$dataset->id,
                "Format" => "image/png",
                Resolutions => "9..19",
                SRS => "EPSG:3067",
                BoundingBox => $config->{BoundingBox3067},
                file => "/home/ajolma/data/SmartSea/mask.tiff", #fixme wrong path
                ext => "png"
            };
        }
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
    
    unless ($epsg) {
        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->Create(
            Name => "/vsimem/r.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>$epsg));
        say STDERR "NO EPSG!";
        return $ds;
    }

    for my $key (sort keys %$params) {
        #say STDERR "$key => ",($params->{$key} // 'undef');
    }
    
    my @t = $tile->tile;
    my @pw = $tile->projwin;
    #say STDERR "@pw";
    
    my $want = $params->{layer} // $params->{layers};

    # the client asks for plan_use_layer_rule_rule_...
    # rules are those rules that the client wishes to be active
    # no rules = all rules?

    $self->{cookie} = $server->{request}->cookies->{SmartSea} // 'default';

    my $style = $params->{style} // 'grayscale';
    $style =~ s/-/_/g;
    $style =~ s/\W.*$//g;
    
    my $layer = SmartSea::Rules->new({
        epsg => $epsg,
        tile => $tile,
        schema => $self->{schema},
        data_dir => $self->{data_dir},
        GDALVectorDataset => $self->{GDALVectorDataset},
        cookie => $self->{cookie}, 
        trail => $want
    });

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
        $ds->Band(1)->ColorTable($self->{palette}{suomi});
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

    my $palette = {palette => $style};
    my $classes = $layer->classes;
    $palette->{classes} = $classes if defined $classes;
    $palette = SmartSea::Palette->new($palette);

    my ($min, $max) = $layer->range;
    
    my $result = $layer->mask();
    my $mask = $result->Band->Piddle; # 0 = out / 1 =  in / bad (255) = out

    my $y;
    eval {
        $y = $layer->compute();
    };
    say STDERR $@ if $@;

    $y->inplace->copybad($mask);

    $classes //= 101;
    unless ($mask->min eq 'BAD') {
        # scale and bound to min .. max => 0 .. $classes-1
        # note that the first and last ranges are half of others
        --$classes;
        $y = $classes*($y-$min)/($max-$min)+0.5;
        $y->where($y > $classes) .= $classes;
        $y->where($y < 0) .= 0;
    }

    $y->where($mask == 0) .= 255;
    $y->inplace->setbadtoval(255);

    $result->Band->Piddle(byte $y);
    $result->Band->ColorTable($palette->color_table);

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
