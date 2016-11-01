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
use Data::Dumper;
use Geo::OGC::Service;
use DBI;

use SmartSea::Schema;

binmode STDERR, ":utf8"; 

sub new {
    my ($class, $self) = @_;
    my $dsn = "dbi:Pg:dbname=$self->{dbname}";
    $self->{dbh} = DBI->connect($dsn, $self->{user}, $self->{pass}, {});
    $self->{schema} = SmartSea::Schema->connect($dsn, $self->{user}, $self->{pass}, {});
    $dsn = "PG:dbname='$self->{dbname}' host='localhost' port='5432'";
    $self->{GDALVectorDataset} = Geo::GDAL::Open(
        Name => "$dsn user='$self->{user}' password='$self->{pass}'",
        Type => 'Vector');
    return bless $self, $class;
}

sub config {
    my ($self, $config) = @_;

    my @tilesets = ();

    my $uses = $self->{dbh}->selectall_arrayref("select use_id,layer_id from tool.uses_list");
    my $plans = $self->{dbh}->selectall_arrayref("select id from tool.plans");

    my $tileset = sub {
        my $title = shift;
        return {
            Layers => $title,
            'Format' => 'image/png',
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => "$self->{data_path}/corine-sea.tiff",
            ext => "png",
            'no-cache' => 1,
        };
    };
    
    for my $row (@$uses) {
        my $l = lc($row->[0] .'_'. $row->[1]);
        $l =~ s/ /_/g;
        if ($row->[1] eq '3') { # Allocation
            for my $row (@$plans) {
                $row->[0] =~ s/ /_/g;
                push @tilesets, $tileset->($l.'_'.lc($row->[0]));
            }
        } else {
            push @tilesets, $tileset->($l);
        }
    }

    for my $protocol (qw/TMS WMS WMTS/) {
        $config->{$protocol}->{TileSets} = \@tilesets;
    }

    return $config;
}

sub process {
    my ($self, $dataset, $tile, $params) = @_;

    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin] );
    $dataset->Band(1)->ColorTable(value_color_table());
    
    my ($use, $layer, $plan);
    if ($params->{layer} =~ /^(\w+)_(\w+)_(\w+)/) {
        $use = $self->{schema}->resultset('Use')->single({ id => $1 })->title;
        $layer = $self->{schema}->resultset('Layer')->single({ id => $2 })->data;
        $plan = $self->{schema}->resultset('Plan')->single({ id => $3 })->title;
    } elsif ($params->{layer} =~ /^(\w+)_(\w+)/) {
        $use = $self->{schema}->resultset('Use')->single({ id => $1 })->title;
        $layer = $self->{schema}->resultset('Layer')->single({ id => $2 })->data;
        $plan = '';
    } else {
        return $dataset;
    }

    if ($use eq 'Protected areas') {
        return $self->mpa_layer($dataset, $tile, $layer, $plan);
    } elsif ($use eq 'Fisheries') {
        return $self->fish_layer($dataset, $tile, $layer, $plan);
    } elsif ($use eq 'Offshore wind farms') {
        return $self->wind_layer($dataset, $tile, $layer, $plan);
    } elsif ($use eq 'Fish farming') {
        return $dataset;
    } elsif ($use eq 'Geoenergy extraction') {
        return $dataset;
    } elsif ($use eq 'Disposal of dredged material') {
        return $dataset;
    } elsif ($use eq 'Coastal turism') {
        return $dataset;
    } elsif ($use eq 'Seabed mining') {
        return $dataset;
    } else {
        return $dataset;
    }
}

sub mpa_layer {
    my ($self, $dataset, $tile, $layer, $plan) = @_;
    if ($layer eq 'Allocation') {
        my $data = $dataset->Band(1)->Piddle;
        $data .= 0;
        $dataset->Band(1)->Piddle($data);
        $self->{GDALVectorDataset}->Rasterize($dataset, [-burn => 1, -l => 'naturakohde_meri_ma']);
        $dataset->Band(1)->ColorTable(allocation_color_table());
    }
    return $dataset;
}

sub fish_layer {
    my ($self, $dataset, $tile, $layer, $plan) = @_;
    if ($layer eq 'Value') {
        my $data = $dataset->Band(1)->Piddle;
        $data .= 0;
        $dataset->Band(1)->Piddle($data);
        $self->{GDALVectorDataset}->Rasterize($dataset, [-burn => 3, -l => 'plan bothnia.fishery']);
        $dataset->Band(1)->ColorTable(value_color_table());
    }
    return $dataset;
}

sub wind_layer {
    my ($self, $dataset, $tile, $layer, $plan) = @_;
    if ($layer eq 'Value') {
        my $wind = Geo::GDAL::Open("$self->{data_path}/tuuli/WS_100M/WS_100M.tif")
            ->Translate( "/vsimem/tmp.tiff", 
                         ['-of' => 'GTiff', '-r' => 'nearest' , 
                          '-outsize' , $tile->tile,
                          '-projwin', $tile->projwin] )
            ->Band(1)
            ->Piddle;

        $wind *= $wind > 0;

        # wind = 5.2 ... 9.7
        my $data = $dataset->Band(1)->Piddle;

        $data .= 4;

        $data -= $wind < 8.5; # 3 where wind < 8
        $data -= $wind < 7; # 2 where wind < 7
        $data -= $wind < 6; # 1 where wind < 6
        $data -= $wind <= 0; # 0 where wind <= 0
        
        $dataset->Band(1)->Piddle($data);
        $dataset->Band(1)->ColorTable(value_color_table());
    } elsif ($layer eq 'Allocation') {
        my $data = $dataset->Band(1)->Piddle;
        $data .= 0;
        $dataset->Band(1)->Piddle($data);
        if ($plan eq 'Plan Bothnia') {
            $self->{GDALVectorDataset}->Rasterize($dataset, [-burn => 2, -l => 'plan bothnia.energy']);
        } else {
        }
        $dataset->Band(1)->ColorTable(allocation_color_table());
    }
    return $dataset;
}

sub value_color_table {
    my $ct = Geo::GDAL::ColorTable->new();
    $ct->Color(0, [0,0,0,0]); # no data
    $ct->Color(1, [255,255,255,255]); # no value
    $ct->Color(2, [255,237,164,255]); # some value
    $ct->Color(3, [255,220,78,255]); # valuable
    $ct->Color(4, [255,204,0,255]); # high value
    return $ct;
}

sub allocation_color_table {
    my $ct = Geo::GDAL::ColorTable->new();
    $ct->Color(0, [0,0,0,0]); # no data
    $ct->Color(1, [85,255,255,255]); # current use
    $ct->Color(2, [255,66,61,255]); # new allocation
    return $ct;
}

1;
