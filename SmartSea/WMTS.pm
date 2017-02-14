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
use Geo::OGC::Service;
use DBI;

use SmartSea::Core qw(:all);
use SmartSea::Schema;
use SmartSea::Rules;

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
        Name => "Pg:dbname=suomi user='ajolma' password='ajolma'",
        Type => 'Vector');

    my $ct = Geo::GDAL::ColorTable->new();
    $self->{palette}{red_and_green} = $ct;
    $ct->Color(0, [255,0,0,255]);
    $ct->Color(1, [0,255,0,255]);
    $ct->Color(255, [0,0,0,0]);

    $ct = Geo::GDAL::ColorTable->new();
    $self->{palette}{red_to_green} = $ct;
    for my $value (0..100) {
        $ct->Color($value, [255*(100-$value)/100,255*$value/100,0,255]);
    }
    $ct->Color(255, [0,0,0,0]);

    $ct = Geo::GDAL::ColorTable->new();
    $self->{palette}{to_green} = $ct;
    for my $value (0..100) {
        my $hsv = Imager::Color->new(
            hsv => [ 120, $value/100, $value/100 ]
            );
        my @rgb = $hsv->rgba;
        $rgb[3] = 255*$value/100;
        $ct->Color($value, \@rgb);
    }
    $ct->Color(255, [0,0,0,0]);

    $ct = Geo::GDAL::ColorTable->new();
    $self->{palette}{suomi_colortable} = $ct;
    $ct->Color(0, [255,255,255,255]);
    $ct->Color(1, [180,180,180,255]);
    $ct->Color(2, [150,150,150,255]);
    $ct->Color(3, [10,10,10,255]);

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
                    file => "/home/ajolma/data/SmartSea/mask.tiff",
                    ext => "png"
                };
            }
        }
        for my $dataset ($self->{schema}->resultset('Dataset')->all) {
            next unless $dataset->path;
            push @tilesets, {
                Layers => "dataset_".$dataset->id,
                "Format" => "image/png",
                Resolutions => "9..19",
                SRS => "EPSG:3067",
                BoundingBox => $config->{BoundingBox3067},
                file => "/home/ajolma/data/SmartSea/mask.tiff",
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

    my @t = $tile->tile;
    my @pw = $tile->projwin;
    #say STDERR "$params->{tilematrixset}, @t, @pw";

    # WMTS clients ask for layer
    # WMS clients ask for layers

    my $want = $params->{layer} // $params->{layers};
    say STDERR $want;

    # the client asks for plan_use_layer_rule_rule_...
    # rules are those rules that the client wishes to be active
    # no rules = all rules?

    $self->{cookie} = $server->{request}->cookies->{SmartSea} // 'default';
    
    my $rules = SmartSea::Rules->new({
        tilematrixset => $params->{tilematrixset},
        tile => $tile,
        schema => $self->{schema},
        data_dir => $self->{data_dir},
        GDALVectorDataset => $self->{GDALVectorDataset},
        cookie => $self->{cookie}, 
        trail => $want
    });

    if ($rules->{dataset}) {
        my $min = $rules->{dataset}->min_value // 0;
        my $max = $rules->{dataset}->max_value // 1;
        $max = $min + 1 if $max - $min == 0;
        my $dataset = mask($rules);
        my $mask = $dataset->Band->Piddle; # 0 / 1
        
        my $y;
        eval {
            $y = $rules->{dataset}->Piddle($rules);
        };
        
        $y->inplace->copybad($mask);
        unless ($mask->min eq 'BAD') {
            # scale and bound to min .. max => 0 .. 100
            $y = 100*($y-$min)/($max-$min);
            $y->where($y > 100) .= 100;
            $y->where($y < 0) .= 0;
        }
        $y->inplace->setbadtoval(255);
        $y->where($mask == 0) .= 255;
        $dataset->Band->Piddle(byte $y);
        $dataset->Band->ColorTable($self->{palette}{to_green});

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
        $ds->Band(1)->ColorTable($self->{palette}{suomi_colortable});
        $self->{Suomi}->Rasterize($ds, [-burn => 1, -l => 'f_l1_3067']);
        $self->{Suomi}->Rasterize($ds, [-burn => 2, -l => $layer]);
        $self->{Suomi}->Rasterize($ds, [-burn => 3, -l => 'maakunnat_rajat']);
        $self->{Suomi}->Rasterize($ds, [-burn => 3, -l => 'eez_rajat']);

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
        return $ds;
    }

    # a 0/1 mask of the planning area
    $dataset = mask($rules);

    my $mask = $dataset->Band(1)->Piddle; # 0 / 1
    #say STDERR "min=",$mask->min." max=".$mask->max;

    $self->{log} = '';

    my $y = $rules->compute($tile, $self); # sequential: 0 or 1, multiplicative: 0 to 1, additive: 0 to max
    $y->inplace->copybad($mask);
    unless ($mask->min eq 'BAD') {
        $y->inplace->setbadtoval(255);
        if ($rules->{class}->name =~ /^seq/) {     
            $y *= 100;
        } else {
            $y *= 100;
            #$self->{log} .= "\noutput: min=".$y->min." max=".$y->max;
            #say STDERR $self->{log};
        }
        $y->where($mask == 0) .= 255;
    }

    my $palette = 'to_green';
    $palette = $params->{style} if $params->{style} && exists $self->{palette}{$params->{style}};

    $dataset->Band(1)->ColorTable($self->{palette}{$palette});
    $dataset->Band(1)->Piddle(byte $y);
  
    return $dataset;
}

sub mask {
    my $rules = shift;
    my $tile = $rules->{tile};
    my $dataset = Geo::GDAL::Open("$rules->{data_dir}/mask.tiff");
    if ($rules->{tilematrixset} eq 'ETRS-TM35FIN') {
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
              -t_srs => $rules->{tilematrixset},
              -te => @$e,
              -ts => $tile->tile] );
    }
    return $dataset;
}

1;
