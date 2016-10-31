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

binmode STDERR, ":utf8"; 

#my $dbname = 'Gob';
#my $user = 'smartsea';
#my $pass = 'SGnwsLmA9yoHg';
#my $db = "PG:dbname='$dbname' host='localhost' port='5432' user='$user' password='$pass'";
#my $data_path = '/home/cloud-user/data';

my $dbname = 'SmartSea';
my $user = 'ajolma';
my $pass = 'ajolma';
my $db = "PG:dbname='$dbname' host='localhost' port='5432' user='$user' password='$pass'";
my $data_path = '/home/ajolma/data/SmartSea';

sub new {
    my ($class, $parameters) = @_;
    my $self = {};
    $self->{plan} = Geo::GDAL::Open(
        Name => $db,
        Type => 'Vector');
    #my @l = $self->{plan}->GetLayerNames;
    #print STDERR "layers = @l\n";
    $self->{depth} = Geo::GDAL::Open("$data_path/depth-classes.tiff");
    $self->{natura} = Geo::GDAL::Open("$data_path/natura.tiff");
    $self->{VelmuSyvyys} = Geo::GDAL::Open("$data_path/VelmuSyvyys/VelmuSyvyysEez.tif");
    $self->{surf_sal} = Geo::GDAL::Open("$data_path/surf_sal/surf_sal_final.tif");
    return bless $self, $class;
}

sub config {
    my ($self, $config) = @_;

    my @tilesets = ();

    my $dbh = DBI->connect("dbi:Pg:dbname=$dbname", $user, $pass, {AutoCommit => 0});
    my $uses = $dbh->selectall_arrayref("select use_id,layer_id from tool.uses_list");
    my $plans = $dbh->selectall_arrayref("select id from tool.plans");

    my $tileset = sub {
        my $title = shift;
        return {
            Layers => $title,
            'Format' => 'image/png',
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => "/home/ajolma/data/SmartSea/corine-sea.tiff",
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

    say STDERR $params->{layer};

    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin] );
    my $data = $dataset->Band()->Piddle;

    my $depth = $self->{depth}->Translate( "/vsimem/d.tiff", 
                                           ['-of' => 'GTiff', '-r' => 'nearest' , 
                                            '-outsize' , $tile->tile,
                                            '-projwin', $tile->projwin] )
        ->Band()->Piddle;
    my $natura = $self->{natura}->Translate( "/vsimem/n.tiff", 
                                             ['-of' => 'GTiff', '-r' => 'nearest' , 
                                              '-outsize' , $tile->tile,
                                              '-projwin', $tile->projwin] )
        ->Band()->Piddle;
    my $velmu_depth = $self->{depth}->Translate( "/vsimem/v.tiff",
                                                 ['-of' => 'GTiff', '-r' => 'nearest' ,
                                                  '-outsize' , $tile->tile,
                                                  '-projwin', $tile->projwin] )
        ->Band()->Piddle;

    #$self->{plan}->Rasterize($dataset, [-a => 'value', -l => 'plan']);
    #$self->{plan}->Rasterize($dataset, [-burn => 1, -l => 'merged']);

    if ($params->{layer} eq 'fisheries_value') {
        $data *= 0;
        $dataset->Band()->Piddle($data);
        $self->{plan}->Rasterize($dataset, [-burn => 1, -l => 'energy_scenarios']);

        my $ct = Geo::GDAL::ColorTable->new();
        # 0 is no data                                                                                     
        $ct->Color(1, [0,0,0]);
        $dataset->Band()->ColorTable($ct);

        return $dataset;
    }
    if ($params->{layer} eq 'protected_areas_allocation') {
        $data *= 0;
	$dataset->Band()->Piddle($data);

        $self->{plan}->Rasterize($dataset, [-burn => 1, -l => 'naturakohde_ma']);

        my $ct = Geo::GDAL::ColorTable->new();
        # 0 is no data                                                                                     
	$ct->Color(1, [85,255,255]);
        $dataset->Band()->ColorTable($ct);

        return $dataset;
    }
    if ($params->{layer} eq 'offshore_wind_farms_value') {

        #print STDERR $velmu_depth->range([0,10],[0,10]);                                                  
        $dataset->Band()->Piddle($velmu_depth);

        my $ct = Geo::GDAL::ColorTable->new();
        # 0 is no data                                                                                     
        my $k = (0-255)/(10-1);
        for my $d (1..10) {
            my $r = 255+$k*($d-1);
            $ct->Color($d, $r, 255, 255);
        }
        for my $d (1..10) {
            my $g = 255+$k*($d-1);
            $ct->Color(10+$d, 0, $g, 255);
        }
        $dataset->Band()->ColorTable($ct);

        return $dataset;
    }
    if ($params->{layer} eq 'fish_farming_suitability') {
        $dataset = $self->{surf_sal}->Translate( "/vsimem/sal.tiff",
                                                 ['-of' => 'GTiff', '-r' => 'nearest',
                                                  '-scale' => '0.894 7.272',
                                                  '-a_nodata' => '0',
                                                  '-outsize' , $tile->tile,
                                                  '-projwin', $tile->projwin] );
        #say STDERR $surf_sal;                                                                             
        #$dataset->Band()->Piddle($surf_sal);                                                              
	return $dataset;
    }

    # data:
    # 1 and 3 are territorial sea
    # 2 is eez
    # depth: 1=shallow, 2=transitional, 3=deep
    # natura: 0=no / !0=yes

    my $not_suitable = 1;
    my $suitable_with_conditions = 2;
    my $suitable = 3;

    my $result = $data*0;
    my $i = $result->where($depth == 1);
    $i .= $suitable;
    $i = $result->where($depth == 2);
    $i .= $suitable_with_conditions;
    $i = $result->where($depth == 3);
    $i .= $not_suitable;
    $i = $result->where($natura > 0);
    $i .= $not_suitable;
    $i = $result->where($data == 0);
    $i .= 0;

    $dataset->Band()->Piddle($result);
    
    my @not_suitable = (255,66,61);
    my @suitable_with_conditions = (255,133,61);
    my @suitable = (31,203,10);

    my $ct = Geo::GDAL::ColorTable->new();

    say STDERR $params->{layer};
    if ($params->{layer} eq 'fisheries_value') {
        $ct->Color($not_suitable, \@suitable);
        $ct->Color($suitable_with_conditions, \@suitable);
        $ct->Color($suitable, \@suitable);
    } else {
        $ct->Color($not_suitable, \@not_suitable);
        $ct->Color($suitable_with_conditions, \@suitable_with_conditions);
        $ct->Color($suitable, \@suitable);
    }
    $dataset->Band(1)->ColorTable($ct);

    return $dataset;
}

1;
