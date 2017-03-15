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
    
    my $rules = SmartSea::Rules->new({
        epsg => $epsg,
        tile => $tile,
        schema => $self->{schema},
        data_dir => $self->{data_dir},
        GDALVectorDataset => $self->{GDALVectorDataset},
        cookie => $self->{cookie}, 
        trail => $want
    });

    if ($rules->{dataset}) {
        #say STDERR "dataset=".$rules->{dataset}->name;
        #say STDERR "style=$style";

        my $palette = {palette => $style};
        my $classes = $rules->{dataset}->classes;
        $palette->{classes} = $classes if defined $classes;
        $palette = SmartSea::Palette->new($palette);
        
        my $min = $rules->{dataset}->min_value // 0;
        my $max = $rules->{dataset}->max_value // 1;
        $max = $min + 1 if $max - $min == 0;
        
        my $dataset = mask($rules);
        my $mask = $dataset->Band->Piddle; # 0 / 1
        
        my $y;
        eval {
            $y = $rules->{dataset}->Piddle($rules);
        };
        say STDERR $@ if $@;
        
        $y->inplace->copybad($mask);

        $classes //= 101;
        unless ($mask->min eq 'BAD') {
            # scale and bound to min .. max => 0 .. $classes-1
            --$classes;
            $y = $classes*($y-$min)/($max-$min); #+0.5;
            $y->where($y > $classes) .= $classes;
            $y->where($y < 0) .= 0;
        }
        $y->inplace->setbadtoval(255);
        $y->where($mask == 0) .= 255;
        
        $dataset->Band->Piddle(byte $y);
        $dataset->Band->ColorTable($palette->color_table);

        # Cache-Control should be only max-age=seconds something
        return $dataset;
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
        $ds->Band(1)->ColorTable($self->{palette}{suomi});
        $self->{Suomi}->Rasterize($ds, [-burn => 1, -l => 'f_l1_3067']);
        $self->{Suomi}->Rasterize($ds, [-burn => 2, -l => $layer]);
        $self->{Suomi}->Rasterize($ds, [-burn => 3, -l => 'maakunnat_rajat']);
        $self->{Suomi}->Rasterize($ds, [-burn => 3, -l => 'eez_rajat']);

        #say STDERR $want;

        # Cache-Control should be only max-age=seconds something
        return $ds;
    }

    unless ($rules->{layer}) {
        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->
            Create(Name => "/vsimem/suomi.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>3067));
        say STDERR "no layer";
        return $ds;
    }

    # a 0/1 mask of the planning area
    
    $dataset = mask($rules);

    my $mask = $dataset->Band->Piddle; # 0 = out / 1 =  in / bad (255) = out
    $mask->where($mask == 0) .= 255; # 1 or bad

    # colortable values are 0..100 and 255 for transparent (out)

    my $debug = 0;

    if ($mask->min eq 'BAD') {

        $dataset->Band->Piddle($mask);
        
    } else {

        my $y = $rules->compute($debug);
        if ($debug) {
            say STDERR 
                "result counts 0:",count($y, 0, $tile->tile),
                " 1:",count($y, 1, $tile->tile);
        }
    
        $y->inplace->copybad($mask);

        if ($debug) {
            say STDERR 
                "result counts 0:",count($y, 0, $tile->tile),
                " 1:",count($y, 1, $tile->tile),
                " 255:",count($y, 255, $tile->tile);
        }

        # y is, if sequential: 0 or 1, multiplicative: 0 to 1, additive: 0 to max
        $y *= 100;

        $y->where($mask == 0) .= 255;
        if ($debug) {
            my @stats = stats($y); # 3 and 4 are min and max
            my $ones = count($y, 100, $tile->tile);
            say STDERR "masked result min=$stats[3], max=$stats[4] count=$ones";
        }
        $y->inplace->setbadtoval(255);

        $dataset->Band->Piddle(byte $y);
        
    }

    $dataset->Band->ColorTable($self->{palette}{$style});

    # Cache-Control must be 'no-cache, no-store, must-revalidate'
    # since rules may change
    return $dataset;
}

sub count {
    my ($x, $val, @size) = @_;
    my $ones = zeroes(@size);
    $ones->where($x == $val) .= 1;
    return $ones->sum;
}

sub mask {
    my $rules = shift;
    my $tile = $rules->{tile};
    my $dataset = Geo::GDAL::Open("$rules->{data_dir}/mask.tiff");
    if ($rules->{epsg} == 3067) {
        $dataset = $dataset->Translate( 
            "/vsimem/tmp.tiff", 
            [ -ot => 'Byte', 
              -of => 'GTiff', 
              -r => 'nearest' , 
              -outsize => $tile->tile,
              -projwin => $tile->projwin,
              -a_ullr => $tile->projwin ]);
    } else {
        my $e = $tile->extent;
        $dataset = $dataset->Warp( 
            "/vsimem/tmp.tiff", 
            [ -ot => 'Byte', 
              -of => 'GTiff', 
              -r => 'near' ,
              -t_srs => 'EPSG:'.$rules->{epsg},
              -te => @$e,
              -ts => $tile->tile] );
    }
    return $dataset;
}

1;
