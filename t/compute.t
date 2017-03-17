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

my $data_schema  = SmartSea::Schema->connect('dbi:SQLite:data.db');
my $tool_schema  = SmartSea::Schema->connect('dbi:SQLite:tool.db');

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

# set up the mask

my $x_min = 61600.000;
my $y_max = 7304000.000;
my $cell_wh = 20.0;
my $data_wh = 3;

{
    my $mask = Geo::GDAL::Driver('GTiff')->Create(
        Name => '/vsimem/mask.tiff',
        Type => 'Byte',
        Width => $data_wh, 
        Height => $data_wh)->Band;
    $mask->Dataset->GeoTransform($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    $mask->WriteTile([[255,1,1],[1,1,1],[1,1,1]]);
}

# the tile that we'll ask the layer to compute
my $tile = Tile->new([$data_wh,$data_wh, $x_min,$y_max,$x_min+$cell_wh*$data_wh,$y_max-$cell_wh*$data_wh]);

# set up the test database

my $schema = Schema->new([[$data_schema, {Dataset => 1}], [$tool_schema, {Style => 1}]]);

my $style_rs = $schema->resultset('Style');
$style_rs->update_or_new({id => 1, name => 'grayscale'}, {key => 'primary'})->insert;

my @styles;

# set up datasets

my $dataset_rs = $schema->resultset('Dataset');

# test computing a layer
# there are three methods a layer can be computed 
# + a layer can be based on a dataset
#
# layer can have multiple styles

my $debug = 1;

for my $datatype (qw/Byte Int16 Int32 Float32 Float64/) {
    for my $style ($style_rs->all) {
        for my $classes (undef, 2, 10) {
            make_dataset(1, [0,120], $classes, $datatype, [[1,2,3],[150,160,180],[0,16,17]], $style->id);
       
            #print Geo::GDAL::Open(Name => '/vsimem/test.tiff')->Band->Piddle if $debug;
            
            my $layer = SmartSea::Layer->new({
                epsg => 3067,
                tile => $tile,
                schema => $schema,
                data_dir => '/vsimem',
                GDALVectorDataset => undef,
                cookie => '', 
                trail => '0_0_1'});
            
            my $palette = SmartSea::Palette->new({palette => $style->name, classes => $layer->classes});
            
            my $result = $layer->compute($palette->{classes}, 0); #$debug);
            
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
            
            print $result->Band->Piddle() if !$ok && $debug;
            
        }

    }
}

done_testing();

sub make_dataset {
    my ($id, $range, $classes, $datatype, $data, $style_id) = @_;
    $dataset_rs->update_or_new(
        {id => $id, 
         name => $id,
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
        Name => "/vsimem/$id.tiff",
        Type => $datatype, 
        Width => $data_wh, 
        Height => $data_wh)->Band;
    $test->Dataset->GeoTransform($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    $test->WriteTile($data);
}
