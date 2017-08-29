# here we should test the tile server
# start by testing a dataset layer

use Modern::Perl;
use Geo::GDAL qw/Open/;
use Test::More;

use lib '.';
use Test::Helper;
use Data::Dumper;

use SmartSea::Schema::Result::NumberType qw/:all/;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Layer');

create_test_databases();

my $schema = SmartSea::Schema->connect(
    'dbi:SQLite:tool.db', 
    undef, 
    undef, 
    {on_connect_do => ["ATTACH 'data.db' AS aux"]}
    );

my $tile = Tile->new;
my ($w, $h) = $tile->size;

my $mask = Geo::GDAL::Driver('GTiff')->Create
    (
     Name => $tile->data_dir.'mask.tiff',
     Type => 'Byte',
     Width => $w, 
     Height => $h
    );
$mask->GeoTransform($tile->geotransform);
$mask->Band->WriteTile([[1,1,1],[1,1,1],[1,1,1]]);

my $number_type_rs = $schema->resultset('NumberType');
$number_type_rs->new({id => INTEGER_NUMBER, name => 'integer'})->insert;
$number_type_rs->new({id => REAL_NUMBER, name => 'real'})->insert;

my $data = [[1,0,1],[0,1,0],[1,0,1]];
{
    my $filename = 'dataset.tiff';
    my $dataset = Geo::GDAL::Driver('GTiff')->Create
        (
         Name => $tile->data_dir.$filename,
         Type => 'Byte',
         Width => $w, 
         Height => $h
        )
        ->Band;
    $dataset->Dataset->GeoTransform($tile->geotransform);
    $dataset->WriteTile($data);
    
    my $gt = $dataset->Dataset->GeoTransform;

    $schema->resultset('Dataset')->new(
        {
            id => 1,
            name => "dataset_1",
            path => $filename,
            min_value => 0,
            max_value => 1,
            data_type => INTEGER_NUMBER
        })
        ->insert;
}

my $layer = SmartSea::Layer->new(
    {
        mask => $mask,
        schema => $schema,
        tile => $tile,
        epsg => $tile->epsg,
        data_dir => $tile->data_dir,
        debug => 0,
        trail => '0_1'
    });

ok(ref $layer eq 'SmartSea::Layer', "layer done");
ok(ref $layer->legend eq 'GD::Image', "legend done");

my $result = $layer->compute;
my $data2 = $result->Band->Piddle->unpdl;
is_deeply($data2, $data, "result is ok");

my @colors = $result->Band->ColorTable->Colors;
is_deeply($colors[0], [0,0,0,255], "color 1 is ok");
is_deeply($colors[1], [255,255,255,255], "color 2 is ok");

done_testing();

