use Modern::Perl;
use File::Basename;
use Geo::GDAL;
use Test::More;

use lib '.';
use Test::Helper;

use SmartSea::Schema::Result::RuleClass qw(:all);
use_ok('SmartSea::Schema');
use_ok('SmartSea::Layer');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

my $tile = Tile->new;

# set up the mask (the layer reads it from its datasource)

{
    my ($w, $h) = $tile->size;
    my $mask = Geo::GDAL::Driver('GTiff')->Create(
        Name => $tile->data_dir.'mask.tiff',
        Type => 'Byte',
        Width => $w, 
        Height => $h)->Band;
    $mask->Dataset->GeoTransform($tile->geotransform);
    $mask->WriteTile([[255,1,1],[1,1,1],[1,1,1]]);
}

# set up the test database

$schema->resultset('Plan')->new({id => 1, name => 'plan'})->insert;
$schema->resultset('UseClass')->new({id => 2, name => 'use_class'})->insert;
for my $i (1..4) {
    $schema->resultset('LayerClass')->new({id => $i, name => 'layer_'.$i})->insert;
}

$schema->resultset('Plan')->single({id => 1})
    ->create_related('uses', {id => 1, plan => 1, 'use_class' => 2});

my $rule_class_rs = $schema->resultset('RuleClass');
$rule_class_rs->new({id => EXCLUSIVE_RULE, name => 'exclusive'})->insert;
$rule_class_rs->new({id => MULTIPLICATIVE_RULE, name => 'multiplicative'})->insert;
$rule_class_rs->new({id => ADDITIVE_RULE, name => 'additive'})->insert;
$rule_class_rs->new({id => INCLUSIVE_RULE, name => 'inclusive'})->insert;

my $color_scale_rs = $schema->resultset('ColorScale');
$color_scale_rs->new({id => 1, name => 'grayscale'})->insert;

my $op_rs = $schema->resultset('Op');
$op_rs->new({id => 1, name => '>='})->insert;
$op_rs->new({id => 2, name => '>'})->insert;
$op_rs->new({id => 3, name => '<='})->insert;
$op_rs->new({id => 4, name => '<'})->insert;
$op_rs->new({id => 5, name => '=='})->insert;
$op_rs->new({id => 6, name => '='})->insert;

my $style_rs = $schema->resultset('Style');
my $dataset_rs = $schema->resultset('Dataset');
my $rule_rs = $schema->resultset('Rule');

# sequences
my $sequences = {
    layer => 1,
    rule => 1,
    dataset => 1,
    style => 1
};

# test a layer that is based on a dataset

test_a_dataset_layer(debug => 0);
test_inclusive_rules(debug => 0);
test_exclusive_rules(debug => 0);
test_multiplicative_rules(debug => 0);
#test_additive_rules(debug => 0);

done_testing();

sub test_additive_rules {
    my %args = @_;
    my $color_scale = $color_scale_rs->single({id=>1}); #grayscale, no meaning here

    my $dataset_1 = make_dataset($schema, $sequences, $tile, 'Byte', [[1,2,3],[4,5,6],[7,8,9]]);
    my $dataset_2 = make_dataset($schema, $sequences, $tile, 'Float64', [[1,2,3],[4,5,6],[7,8,9]]); 
    
    my $rule_class = $rule_class_rs->single({id=>ADDITIVE_RULE});
    my $layer = make_layer({
        schema => $schema,
        sequences => $sequences,
        tile => $tile,
        id => $sequences->{layer}++,
        use_class_id => 2,
        layer_class_id => 4,
        style => {
            id => $sequences->{style}++,
            color_scale => $color_scale, 
            min => 0, 
            max => 12,
            classes => 4
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset_1->id },
                data => { 
                    x_min => 1, x_max => 10, y_min => 0, y_max => 1, weight => 2 
                }
            },{
                based => { dataset_id => $dataset_2->id },
                data => { x_min => 1, x_max => 10, y_min => 0, y_max => 1, weight => 1 }
            }
        ]
        });
    my $result = $layer->compute($args{debug});
    
    my $output = $result->Band->ReadTile;
    my $exp = [[255,0,0],[1,2,2],[0,0,0]];
    my $ok = is_deeply($output, $exp, $rule_class->name());
    print $result->Band->Piddle() if !$ok && $args{debug};

}

sub test_multiplicative_rules {
    my %args = @_;
    my $color_scale = $color_scale_rs->single({id=>1}); #grayscale, no meaning here

    my $datatype = 'Int32';
    my $dataset = make_dataset($schema, $sequences, $tile, $datatype, [[1,2,3],[150,160,180],[0,16,17]]);
    
    my $rule_class = $rule_class_rs->single({id=>MULTIPLICATIVE_RULE}); # multiplicative
    my $layer = make_layer({
        schema => $schema,
        sequences => $sequences,
        tile => $tile,
        id => $sequences->{layer}++,
        use_class_id => 2,
        layer_class_id => 3,
        style => {
            id => $sequences->{style}++,
            color_scale => $color_scale,
            min => 0, 
            max => 2, 
            classes => 3
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset->id },
                data => { x_min => 1, x_max => 200, y_min => 0, y_max => 1, weight => 2 }
            }]
        });
    my $result = $layer->compute($args{debug});
    
    my $output = $result->Band->ReadTile;
    my $exp = [[255,0,0],[2,2,2],[0,0,0]];
    my $ok = is_deeply($output, $exp, $rule_class->name()." rules with dataset of $datatype");
    print $result->Band->Piddle() if !$ok && $args{debug};

}

sub test_exclusive_rules {
    my %args = @_;
    my $color_scale = $color_scale_rs->single({id=>1}); #grayscale, no meaning here
    
    my $datatype = 'Int32';
    my $dataset = make_dataset($schema, $sequences, $tile, $datatype, [[1,2,3],[150,160,180],[0,16,17]]);
 
    my $rule_class = $rule_class_rs->single({id=>EXCLUSIVE_RULE});
    my $layer = make_layer({
        schema => $schema,
        sequences => $sequences,
        tile => $tile,
        id => $sequences->{layer}++,
        use_class_id => 2,
        layer_class_id => 2, 
        style => {
            id => $sequences->{style}++,
            color_scale => $color_scale,
            min => 0, 
            max => 1, 
            classes => 2
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset->id },
                data => { reduce => 1, op_id => 1, value => 5.0, index => 1 }
            }]
        });
    my $result = $layer->compute($args{debug});
    my $exp = [[255,1,1],[0,0,0],[1,0,0]];
    my $output = $result->Band->ReadTile;
    my $ok = is_deeply($output, $exp, $rule_class->name()." rules with dataset of $datatype");
    print $result->Band->Piddle() if !$ok && $args{debug};
}

sub test_inclusive_rules {
    my %args = @_;
    my $color_scale = $color_scale_rs->single({id=>1}); #grayscale, no meaning here
    
    my $datatype = 'Int32';
    my $dataset = make_dataset($schema, $sequences, $tile, $datatype, [[1,2,3],[150,160,180],[0,16,17]]);
 
    my $rule_class = $rule_class_rs->single({id=>INCLUSIVE_RULE});
    my $layer = make_layer({
        schema => $schema,
        sequences => $sequences,
        tile => $tile,
        id => $sequences->{layer}++,
        use_class_id => 2,
        layer_class_id => 1, 
        style => {
            id => $sequences->{style}++,
            color_scale => $color_scale,
            min => 0, 
            max => 1, 
            classes => 2
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset->id },
                data => { reduce => 1, op_id => 1, value => 5.0, index => 1 }
            }]
        });
    my $result = $layer->compute($args{debug});

    my $output = $result->Band->ReadTile;
    my $exp = [[255,0,0],[1,1,1],[0,1,1]];
    my $ok = is_deeply($output, $exp, $rule_class->name()." rules with dataset of $datatype");
    print $result->Band->Piddle() if !$ok && $args{debug};
}

sub test_a_dataset_layer {
    my %args = @_;
    for my $datatype (qw/Byte Int16 Int32 Float32 Float64/) {
        for my $color_scale ($color_scale_rs->all) {
            for my $classes (undef, 2, 10) {
                my $style = {
                    id => $sequences->{style}++,
                    min => 0, 
                    max => 120, 
                    classes => $classes, 
                    color_scale => $color_scale->id
                };
                
                my $dataset = make_dataset($schema, $sequences, $tile, $datatype, [[1,2,3],[150,160,180],[0,16,17]], $style);
       
                print "Dataset: ",Geo::GDAL::Open(Name => $tile->data_dir.$dataset->id.'.tiff')->Band->Piddle if $args{debug};
                
                my $layer = make_layer(
                    {
                        schema => $schema,
                        sequences => $sequences,
                        tile => $tile,
                        use_class_id => 0,
                        id => $dataset->id, 
                        debug => $args{debug}
                    });
                
                my $result = $layer->compute();

                print "Result: ",$result->Band->Piddle() if $args{debug};
                
                my $output = $result->Band->ReadTile;
                
                my $exp;
                if (!defined $classes) {
                    $exp = [[255,1,2],[100,100,100],[0,13,14]];
                } elsif ($classes == 2) {
                    $exp = [[255,0,0],[1,1,1],[0,0,0]];
                } elsif ($classes == 10) {
                    $exp = [[255,0,0],[9,9,9],[0,1,1]];
                }

                if ($args{debug}) {
                    say "Expected: ";
                    for (@$exp) {
                        say "@$_";
                    }
                }
                my $nclasses = $classes // 'undef';
                my $ok = is_deeply($output, $exp, "dataset with $nclasses classes, $datatype");
                                
            }
            
        }
    }
}
