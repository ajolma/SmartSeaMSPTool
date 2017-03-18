use Modern::Perl;
use File::Basename;
use Geo::GDAL;
use Test::More;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Palette');
use_ok('SmartSea::Layer');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

my $data_schema  = SmartSea::Schema->connect(
    'dbi:SQLite:data.db', undef, undef, 
    {on_connect_do => ["ATTACH 'tool.db' AS aux"]});
my $tool_schema  = SmartSea::Schema->connect(
    'dbi:SQLite:tool.db', undef, undef, 
    {on_connect_do => ["ATTACH 'data.db' AS aux"]});

{
    package Schema;
    sub new {
        my ($class, $self) = @_;
        return bless $self, $class;
    }
    sub resultset {
        my ($self, $class) = @_;
        for my $s (@$self) {
            return $s->[0]->resultset($class) if $s->[1]{$class};
        }
        say STDERR "missing $class";
    }
}

my $schema = Schema->new(
    [
     [$data_schema, {Dataset => 1}], 
     [$tool_schema, 
      { Style => 1, 
        Plan => 1, 
        Use => 1, 
        Plan2Use => 1, 
        Layer => 1, 
        Plan2Use2Layer => 1, 
        RuleClass => 1,
        Op => 1,
        Rule => 1 }]]);

# the tile that we'll ask the layer to compute
{
    package Tile;
    sub new {
        my ($class, $self) = @_;
        bless $self, $class;
    }
    sub tile {
        my ($self) = @_;
        return @{$self}[0..1]; # width, height
    }
    sub projwin {
        my ($self) = @_;
        return @{$self}[2..5]; # minx maxy maxx miny
    }
}

my $epsg = 3067;
my $x_min = 61600.000;
my $y_max = 7304000.000;
my $cell_wh = 20.0;
my $data_wh = 3;

my $tile = Tile->new([$data_wh,$data_wh, $x_min,$y_max,$x_min+$cell_wh*$data_wh,$y_max-$cell_wh*$data_wh]);

# set up the mask (the layer reads it from its datasource)

my $data_dir = '/vsimem/';

{
    my $mask = Geo::GDAL::Driver('GTiff')->Create(
        Name => $data_dir.'mask.tiff',
        Type => 'Byte',
        Width => $data_wh, 
        Height => $data_wh)->Band;
    $mask->Dataset->GeoTransform($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    $mask->WriteTile([[255,1,1],[1,1,1],[1,1,1]]);
}

# set up the test database

$schema->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$schema->resultset('Use')->new({id => 1, name => 'use'})->insert;
$schema->resultset('Plan')->single({id => 1})
    ->create_related('plan2use', {id => 1, plan => 1, 'use' => 1});
$schema->resultset('Layer')->new({id => 1, name => 'layer'})->insert;

my $rule_class_rs = $schema->resultset('RuleClass');
$rule_class_rs->new({id => 1, name => 'sequential'})->insert;
$rule_class_rs->new({id => 2, name => 'multiplicative'})->insert;
$rule_class_rs->new({id => 3, name => 'additive'})->insert;

my $style_rs = $schema->resultset('Style');
$style_rs->new({id => 1, name => 'grayscale'})->insert;

my $op_rs = $schema->resultset('Op');
$op_rs->new({id => 1, name => '>='})->insert;
$op_rs->new({id => 2, name => '>'})->insert;
$op_rs->new({id => 3, name => '<='})->insert;
$op_rs->new({id => 4, name => '<'})->insert;
$op_rs->new({id => 5, name => '=='})->insert;
$op_rs->new({id => 6, name => '='})->insert;

my $dataset_rs = $schema->resultset('Dataset');
my $rule_rs = $schema->resultset('Rule');

# test a layer that is based on a dataset

test_a_dataset_layer(debug => 0);

# test computing a layer
# there are three methods a layer can be computed

my $debug = 2;

test_sequential_rules(debug => 0);

done_testing();

sub test_sequential_rules {
    my %args = @_;
    my $rule_class = $rule_class_rs->single({id=>1}); # sequential
    my $style = $style_rs->single({id=>1});
    
    my $dataset_id = 1;
    my $classes = undef;
    my $datatype = 'Int32';
    make_dataset($dataset_id, [0,120], $classes, $datatype, [[1,2,3],[150,160,180],[0,16,17]], $style->id);

    my $pul = 1;
    
    my $rule = {
        id => 1,
        reduce => 1,
        r_use => undef,
        r_layer => undef,
        r_plan => undef,
        op => 1, # gte
        value => 5.0,	
        r_dataset => $dataset_id,
        min_value => 0,
        max_value => 1,
        my_index => 1,
        value_type => '',	
        cookie => '',
        made => undef,
        value_at_min => 0,
        value_at_max => 1,
        weight => 1,
        plan2use2layer => $pul
    };
    
    $rule_rs->new($rule)->insert;
    
    my $layer = make_layer(
        1,1,1, 
        {
            pul => $pul,
            style => $style, 
            rule_class => $rule_class, 
            min_value => 0, 
            max_value => 1, 
            classes => 2
        });
    my $palette = SmartSea::Palette->new({palette => $style->name, classes => $layer->classes});
    my $result = $layer->compute($palette->{classes}, $args{debug});

    my $output = $result->Band->ReadTile;
    my $exp = [[255,1,1],[0,0,0],[1,0,0]];
    my $ok = is_deeply($output, $exp, $rule_class->name()."rules with dataset of $datatype and ".$style->name);
    print $result->Band->Piddle() if !$ok && $args{debug};
}

sub test_a_dataset_layer {
    my %args = @_;
    for my $datatype (qw/Byte Int16 Int32 Float32 Float64/) {
        for my $style ($style_rs->all) {
            for my $classes (undef, 2, 10) {
                make_dataset(1, [0,120], $classes, $datatype, [[1,2,3],[150,160,180],[0,16,17]], $style->id);
       
                #print Geo::GDAL::Open(Name => $data_dir.'test.tiff')->Band->Piddle if $args{debug};
                
                my $layer = make_layer(0,0,1);
                my $palette = SmartSea::Palette->new({palette => $style->name, classes => $layer->classes});
                my $result = $layer->compute($palette->{classes}, 0); #$args{debug});
                my $output = $result->Band->ReadTile;
                
                my $exp;
                if (!defined $classes) {
                    $exp = [[255,2,3],[100,100,100],[0,13,14]];
                } elsif ($classes == 2) {
                    $exp = [[255,0,0],[1,1,1],[0,0,0]];
                } elsif ($classes == 10) {
                    $exp = [[255,0,0],[9,9,9],[0,1,1]];
                }
                my $nclasses = $classes // 'undef';
                my $ok = is_deeply($output, $exp, "dataset with $nclasses classes, $datatype and ".$style->name);
                
                print $result->Band->Piddle() if !$ok && $args{debug};
                
            }
            
        }
    }
}

sub make_layer {
    my ($plan_id, $use_id, $layer_id, $args) = @_;
    if ($use_id > 0) {
        $schema->resultset('Layer')->single({id => 1})->create_related
            ( 'plan2use2layer', 
              {
                  id => $args->{pul},
                  plan2use => 1, 
                  layer => $layer_id,
                  rule_class => $args->{rule_class}->id,
                  style => $args->{style}->id,
                  min_value => $args->{min_value},
                  max_value => $args->{max_value},
                  classes => $args->{classes}
              });
    }
    return SmartSea::Layer->new({
        epsg => $epsg,
        tile => $tile,
        schema => $schema,
        data_dir => $data_dir,
        GDALVectorDataset => undef,
        cookie => '', 
        trail => $plan_id.'_'.$use_id.'_'.$layer_id});
}

sub make_dataset {
    my ($id, $range, $classes, $datatype, $data, $style_id) = @_;
    $dataset_rs->update_or_new(
        {id => $id, 
         name => "dataset_$id",
         custodian => '',
         contact => '',
         descr => '',
         data_model => undef,
         is_a_part_of => undef,
         is_derived_from => undef,
         license => undef,
         attribution => '',
         disclaimer => '',
         path => $id.'.tiff',
         unit => undef,
         min_value => $range->[0],
         max_value => $range->[1],
         classes => $classes,
         style => $style_id
        }, 
        {key => 'primary'})->insert;
    my $test = Geo::GDAL::Driver('GTiff')->Create(
        Name => $data_dir."$id.tiff",
        Type => $datatype, 
        Width => $data_wh, 
        Height => $data_wh)->Band;
    $test->Dataset->GeoTransform($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    $test->WriteTile($data);
}
