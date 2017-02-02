package SmartSea::WMTS;
use utf8;
use strict;
use warnings;
use 5.010000; # say // and //=
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

    my @tilesets = (
        {
            Layers => "3_3_3_1_26",
            Format => "image/png",
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => "/home/ajolma/data/SmartSea/mask.tiff",
            ext => "png"
        },
        {
            Layers => "3_3_3",
            Format => "image/png",
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => "/home/ajolma/data/SmartSea/mask.tiff",
            ext => "png"
        }
        );

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

    #say STDERR "style = $params->{style}";

    # $dataset is undef since we serve_arbitrary_layers
    # params is a hash of WM(T)S parameters
    #say STDERR "@_";

    if ($params->{layer} eq 'suomi') {

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

    # a 0/1 mask of the planning area
    $dataset = Geo::GDAL::Open("$self->{data_path}/mask.tiff");
    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-ot' => 'Byte', '-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin,
                                     '-a_ullr', $tile->projwin]);

    my $mask = $dataset->Band(1)->Piddle; # 0 / 1
    #say STDERR "min=",$mask->min." max=".$mask->max;

    # the client asks for plan_use_layer_rule_rule_...
    # rules are those rules that the client wishes to be active
    # no rules = all rules?

    my $trail = $params->{layer} // $params->{layers};

    my $cookies = $server->{request}->cookies;
    $self->{cookie} = $cookies->{SmartSea} // 'default';
    #say STDERR "cookie: $self->{cookie}";
    
    my $rules = SmartSea::Rules->new({
        schema => $self->{schema}, 
        cookie => $self->{cookie}, 
        trail => $trail
    });

    $self->{log} = '';

    my $y = $rules->compute($tile, $self); # sequential: 0 or 1, multiplicative: 0 to 1, additive: 0 to max
    $y->inplace->copybad($mask);
    unless ($mask->min eq 'BAD') {
        $y->inplace->setbadtoval(255);
        if ($rules->{class}->title =~ /^seq/) {     
            $y *= 100;
        } else {
            $y *= 100;
            #$self->{log} .= "\noutput: min=".$y->min." max=".$y->max;
            #say STDERR $self->{log};
        }
        $y->where($mask == 0) .= 255;
    }

    my $palette = 'to_green';
    $palette = $params->{style} if exists $self->{palette}{$params->{style}};

    $dataset->Band(1)->ColorTable($self->{palette}{$palette});
    $dataset->Band(1)->Piddle(byte $y);
    return $dataset;

    if ($rules->layer->title eq 'Value') {
        # compute, returns bad, 0..100
        my $value = $rules->compute_value($self, $tile);
        $value->inplace->setbadtoval(-1);
        my $mask = $dataset->Band(1)->Piddle; # 0 / 1
        $mask *= ($value + 2);
        $dataset->Band(1)->Piddle(byte $mask);
        # set color table
        $dataset->Band(1)->ColorTable($self->{value_color_table});
        return $dataset;
    } else {
        # compute, returns 0, 1, 2
        my $allocation = $rules->compute_allocation($self, $tile);
        $allocation->inplace->setbadtoval(0);
        my $mask = $dataset->Band(1)->Piddle; # 0 / 1
        $mask *= $allocation;
        $dataset->Band(1)->Piddle(byte $mask);
        # set color table
        $dataset->Band(1)->ColorTable($self->{allocation_color_table});
        return $dataset;
    }
}

1;
