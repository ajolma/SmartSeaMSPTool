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

use SmartSea::Core qw(:all);
use SmartSea::Schema;

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

    # a 0/1 mask of the planning area
    $dataset = Geo::GDAL::Open("$self->{data_path}/smartsea-mask.tiff");
    $dataset = $dataset->Translate( "/vsimem/tmp.tiff", 
                                    ['-of' => 'GTiff', '-r' => 'nearest' , 
                                     '-outsize' , $tile->tile,
                                     '-projwin', $tile->projwin] );

    # the client asks for use_layer_plan_rule_rule_...
    # _plan_rule_rule_... is optional
    # rules are those rules that the client wishes to be active

    # TODO: use and layer are attributes of rule! and plan is not needed
    # this depends of course on the relationship (1<->1 or n<->n) between those and rule
    # change API? 
    # NO at least as long as rules for Value layers can't be set

    my $s = $params->{layer};
    my $id;
    ($s, $id) = parse_integer($s);
    my $use = $self->{schema}->resultset('Use')->single({ id => $id });
    ($s, $id) = parse_integer($s);
    my $layer = $self->{schema}->resultset('Layer')->single({ id => $id });
    my $plan;
    ($s, $id) = parse_integer($s);
    $plan = $self->{schema}->resultset('Plan')->single({ id => $id }) if $id;

    if ($layer->title eq 'Value') {
        my @rules = SmartSea::Schema::Result::Rule::rules(
            $self->{schema}->resultset('Rule'), $plan, $use, $layer
        );
        # compute, returns bad, 0..100
        my $value = SmartSea::Schema::Result::Rule::compute_value($self, $use, $tile, \@rules);
        $value->inplace->setbadtoval(-1);
        my $mask = $dataset->Band(1)->Piddle; # 0 / 1
        $mask *= ($value + 2);
        $dataset->Band(1)->Piddle(byte $mask);
        # set color table
        $dataset->Band(1)->ColorTable($self->{value_color_table});
        return $dataset;
    } else {
        my @rules;
        while ($s) {
            # rule application order is defined by the client
            ($s, $id) = parse_integer($s);
            my $rule = $self->{schema}->resultset('Rule')->single({ id => $id });
            # maybe we should test $rule->plan and $rule->use?
            # and that the $rule->layer->id is the same?
            push @rules, $rule;
        }
        # compute, returns 0, 1, 2
        my $allocation = SmartSea::Schema::Result::Rule::compute_allocation($self, $use, $tile, \@rules);
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
