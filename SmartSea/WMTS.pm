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

use SmartSea::Core;
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

    for my $protocol (qw/TMS WMS WMTS/) {
        $config->{$protocol}->{TileSets} = \@tilesets;
        $config->{$protocol}->{serve_arbitrary_layers} = 1;
    }

    return $config;
}

sub process {
    my ($self, $dataset, $tile, $params) = @_;
    # $dataset is undef since we serve_arbitrary_layers

    $dataset = Geo::GDAL::Open("$self->{data_path}/corine-sea.tiff");
    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin] );
    $dataset->Band(1)->ColorTable(value_color_table());

    my @arg = ($dataset, $tile);
    my $s = $params->{layer};
    my $id;
    ($s, $id) = parse_integer($s);
    my $use = $self->{schema}->resultset('Use')->single({ id => $id })->title;
    ($s, $id) = parse_integer($s);
    my $layer = $self->{schema}->resultset('Layer')->single({ id => $id })->title;
    my $plan = '';
    ($s, $id) = parse_integer($s);
    $plan = $self->{schema}->resultset('Plan')->single({ id => $id })->title if $id;
    push @arg, $plan, $use, $layer;
    while ($s) {
        # rule application order is defined by the client
        ($s, $id) = parse_integer($s);
        push @arg, $self->{schema}->resultset('Rule')->single({ id => $id });
    }

    for ($use) {
        return $self->mpa_layer(@arg) if /^Protected areas/;
        return $self->fish_layer(@arg) if /^Fisheries/;
        return $self->wind_layer(@arg) if /^Offshore wind farms/;
        return $dataset if /Fish farming/;
        return $dataset if /Geoenergy extraction/;
        return $dataset if /Disposal of dredged material/;
        return $dataset if /Coastal turism/;
        return $dataset if /Seabed mining/;
        return $dataset;
    }
}

sub mpa_layer {
    my ($self, $dataset, $tile, $plan, $use, $layer, @rules) = @_;
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
    my ($self, $dataset, $tile, $plan, $use, $layer, @rules) = @_;
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
    my ($self, $dataset, $tile, $plan, $use, $layer, @rules) = @_;
    if ($layer eq 'Value') {
        my $data = $self->wind_value($dataset, $tile);        
        $dataset->Band(1)->Piddle($data);
        $dataset->Band(1)->ColorTable(value_color_table());
    } elsif ($layer eq 'Allocation') {
        my $data = $dataset->Band(1)->Piddle;
        my $result = $data + 0;

        # default is allocate all
        $result->where($data > 0) .= 2;

        # apply rules
        for my $rule (@rules) {
            # maybe we should test $rule->plan and $rule->use?
            # if $rule->reduce then set to 0 where rule is true

            say STDERR "rule: ",$rule->as_text;

            my $val = $rule->reduce ? 0 : 2;

            # $rule->r_plan, $rule->r_use and $rule->r_layer define the layer to use
            # r_plan is by default plan, r_use is by default use
            # OR
            # $rule->r_table is table name
            # OR
            # rule is non-spatial

            my $op = $rule->op ? $rule->op->op : '';
            my $value = $rule->value;
            my $tmp;

            if ($rule->r_layer) {

                my $r_plan = $rule->r_plan ? $rule->r_plan->title : '';
                my $r_use = $rule->r_use ? $rule->r_use->title : '';
                my $r_layer = $rule->r_layer ? $rule->r_layer->title : '';
                
                if ($r_use eq $use and $r_layer eq 'Value') {
                    $tmp = $self->wind_value($dataset, $tile);                    
                } else {
                    say STDERR "Unsupported layer: $plan.$use.$layer";
                }
            
            } elsif ($rule->r_dataset) {

                my $layer = $rule->r_dataset->path;
                $layer =~ s/^PG://;

                $dataset->Band(1)->Piddle($data*0);
                $self->{GDALVectorDataset}->Rasterize($dataset, [-burn => 1, -l => $layer]);
                $tmp = $dataset->Band(1)->Piddle;

                say STDERR "op and value not supported with tables" if $op || defined $value;

                $op = '==';
                $value = 1;

            } else {
                
                $result .= $val;

            }

            if (defined $tmp) {
                if ($op eq '<=')    { $result->where($tmp <= $value) .= $val; } 
                elsif ($op eq '<')  { $result->where($tmp <  $value) .= $val; }
                elsif ($op eq '>=') { $result->where($tmp >= $value) .= $val; }
                elsif ($op eq '>')  { $result->where($tmp >  $value) .= $val; }
                elsif ($op eq '==') { $result->where($tmp == $value) .= $val; }
                else                {  }
            }
            
        }
        $dataset->Band(1)->Piddle($result);
        $dataset->Band(1)->ColorTable(allocation_color_table());
    }
    return $dataset;
}

sub wind_value {
    my ($self, $dataset, $tile) = @_;
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
    return $data;
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
    $ct->Color(0, [0,0,0,0]); # no data or no allocation
    $ct->Color(1, [85,255,255,255]); # current use
    $ct->Color(2, [255,66,61,255]); # new allocation
    return $ct;
}

1;
