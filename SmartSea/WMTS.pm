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
use Geo::OGC::Service;
use Data::Dumper;

use SmartSea::Core qw(:all);
use SmartSea::App;
use SmartSea::Schema;
use SmartSea::Layer;

binmode STDERR, ":utf8";

# discard warnings - NETCDF driver issues them often
BEGIN {
    $SIG{__WARN__} = sub { }
}

sub new {
    my ($class, $self) = @_;
    
    my $dsn = "PG:dbname='$self->{db_name}' host='localhost' port='5432'";

    $self->{GDALVectorDataset} = Geo::GDAL::Open(
        Name => "$dsn user=$self->{db_user} password=$self->{db_passwd}",
        Type => 'Vector');

    my %dir = map {$_ => 1} Geo::GDAL::ReadDir($self->{data_dir});
    if ($dir{'mask.tiff'}) {
        $self->{mask} = Geo::GDAL::Open($self->{data_dir}.'mask.tiff');
    } else {
        say STDERR "Warning: mask file (mask.tiff) not found";
    }
        
    SmartSea::App::read_bayesian_networks($self);

    return bless $self, $class;
}

sub config {
    my ($self, $config, $server) = @_;
    #print STDERR Dumper $config;

    # QGIS asks for capabilities and does not load unadvertised layers
    
    my @tilesets;
    for my $plan ($self->{schema}->resultset('Plan')->all()) {
        my @uses;
        for my $use ($plan->uses) {
            my @layers;
            for my $layer ($use->layers) {
                push @tilesets, {
                    Layers => $use->use_class->id."_".$layer->id,
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
            Layers => "data_".$dataset->{id},
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
            Layers => "ecosystem_".$component->{id},
            "Format" => "image/png",
            Resolutions => "9..19",
            SRS => "EPSG:3067",
            BoundingBox => $config->{BoundingBox3067},
            file => $self->{data_dir}."mask.tiff",
            ext => "png"
        };
    }

    my %config;
    $config{TileSets} = \@tilesets;
    $config{resource} = $config->{resource};

    return \%config;
}

sub process {
    my ($self, $args) = @_;

    Geo::GDAL->errstr; # clear the error stack

    my $params = $args->{service}{parameters};

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
    
    # the client asks for plan_use_layer_rule_rule_...
    # rules are those rules that the client wishes to be active
    # no rules = all rules

    my $debug = $params->{debug} // 0;
    #$debug += $self->{debug};
    my $layer = $params->{layer} // $params->{layers};

    #my @tile = ($params->{tilematrix},$params->{tilecol},$params->{tilerow});
    #say STDERR "$server->{service}&request=$params->{request}&crs=EPSG:$epsg&layer=$want&tile=@tile";
    #say STDERR "style = $params->{style}";

    my $hugin;
    if ($SmartSea::Schema::Result::RuleSystem::have_hugin) {
        unless ($ENV{HUGINAUTH} && !$args->{service}{env}{REMOTE_USER}) {
            $hugin = 1;
        }
    }
    
    $layer = SmartSea::Layer->new({
        mask => $self->{mask},
        epsg => $epsg,
        tile => $args->{tile},
        schema => $self->{schema},
        data_dir => $self->{data_dir},
        GDALVectorDataset => $self->{GDALVectorDataset},
        cookie => $args->{service}{request}->cookies->{SmartSea}, 
        trail => $layer,
        style => $params->{style},
        domains => $hugin ? $self->{domains} : {},
        debug => $debug });

    my $result = $layer->compute();

    # if $layer is in fact a dataset
    # Cache-Control should be only max-age=seconds something

    # else
    # Cache-Control must be 'no-cache, no-store, must-revalidate'
    # since layer may change

    push @{$args->{headers}}, (
        'Cache-Control' => 'no-cache, no-store, must-revalidate',
        'Pragma' => 'no-cache',
        'Expires' => 0
    );
    
    return $result;
}

1;
