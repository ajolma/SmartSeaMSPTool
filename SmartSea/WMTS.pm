package SmartSea::WMTS;
use utf8;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;
use DBI;
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

    my $ct = Geo::GDAL::ColorTable->new();

    # outside is 0, completely transparent
    $ct->Color(0, [0,0,0,0]);
    # no data is 1, black
    $ct->Color(1, [0,0,0,255]);

    # value is from 0 to 100
    my $max_value = 100;
    # from white to green
    my @color = (255,255,255,255);
    for my $value (0..$max_value) {
        my $c = int(255-255/$max_value*$value);
        @color = ($c,255,$c,255);
        $ct->Color(2+$value, @color);
    }
    $self->{value_color_table} = $ct;

    $ct = Geo::GDAL::ColorTable->new();
    $ct->Color(0, [0,0,0,0]); # no data or no allocation
    $ct->Color(1, [85,255,255,255]); # current use
    $ct->Color(2, [255,66,61,255]); # new allocation
    $self->{allocation_color_table} = $ct;

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
            file => "/home/ajolma/data/SmartSea/smartsea-mask.tiff",
            ext => "png"
        },
        {
            Layers => "3_3_3",
            Format => "image/png",
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => "/home/ajolma/data/SmartSea/smartsea-mask.tiff",
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
    my ($self, $dataset, $tile, $params) = @_;
    # $dataset is undef since we serve_arbitrary_layers
    # params is a hash of WM(T)S parameters

    # a 0/1 mask of the planning area
    $dataset = Geo::GDAL::Open("$self->{data_path}/smartsea-mask.tiff");
    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-ot' => 'Byte', '-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin,
                                     '-a_ullr', $tile->projwin] );

    # the client asks for plan_use_layer_rule_rule_...
    # rules are those rules that the client wishes to be active
    # no rules = all rules?

    my $trail = $params->{layer} // $params->{layers};
    my $rules = SmartSea::Rules->new($self->{schema}, $trail);

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
