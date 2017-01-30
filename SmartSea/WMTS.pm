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

    # value is from 0 to 100
    my $max_value = 100;
    # from white to green
    my @color = (255,255,255,255);
    for my $value (0..$max_value) {
        my $c = int(255-255/$max_value*$value);
        @color = ($c,255,$c,255);
        $ct->Color($value, @color);
    }
    $ct->Color(0, [0,0,0,0]); # outside
    $ct->Color(101, [0,0,0,0]); # no data
    my $i = 0;
    for my $c ($ct->ColorTable) {
        say "$i @$c";
        ++$i;
    }
    $self->{value_color_table} = $ct;

    $ct = Geo::GDAL::ColorTable->new();
    $ct->Color(0, [0,0,0,0]); # no data or no allocation
    $ct->Color(1, [85,255,255,255]); # current use
    $ct->Color(2, [255,66,61,255]); # new allocation
    $self->{allocation_color_table} = $ct;

    # red to green (suitability)
    # R = (255 * (100 - n)) / 100
    # G = (255 * n) / 100 
    # B = 0

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
    my ($self, $dataset, $tile, $server) = @_;
    my $params = $server->{parameters};
    # $dataset is undef since we serve_arbitrary_layers
    # params is a hash of WM(T)S parameters
    #say STDERR "@_";

    # a 0/1 mask of the planning area
    $dataset = Geo::GDAL::Open("$self->{data_path}/smartsea-mask.tiff");
    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-ot' => 'Byte', '-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin,
                                     '-a_ullr', $tile->projwin] );

    my $mask = $dataset->Band(1)->Piddle; # 0 / 1

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
    if ($rules->{class}->title =~ /^seq/) {
        $y += 1;
        $y->inplace->setbadtoval(0);
        # 0 = no data, 1 = rules say no, 2 = rules say yes
        $dataset->Band(1)->ColorTable($self->{allocation_color_table});
    } else {
        $y *= 100;
        $self->{log} .= "\noutput: min=".$y->min." max=".$y->max;
        say STDERR $self->{log};
        $y->inplace->setbadtoval(101);
        # 0 = rules say bad ... 1 = rules say good, 101 no data
        $dataset->Band(1)->ColorTable($self->{value_color_table});
    }
    $y *= $mask;
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
