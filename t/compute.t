use Modern::Perl;
use File::Basename;
use Geo::GDAL;
use Test::More;

use lib '.';
use Test::Helper;

use_ok('SmartSea::Schema');
use_ok('SmartSea::Layer');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

my $options = {on_connect_do => ["ATTACH 'data.db' AS aux"]};
my $schema = SmartSea::Schema->connect('dbi:SQLite:tool.db', undef, undef, $options);

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
$schema->resultset('UseClass')->new({id => 2, name => 'use_class'})->insert;
for my $i (1..4) {
    $schema->resultset('LayerClass')->new({id => $i, name => 'layer_'.$i})->insert;
}

$schema->resultset('Plan')->single({id => 1})
    ->create_related('uses', {id => 1, plan => 1, 'use_class' => 2});

my $rule_class_rs = $schema->resultset('RuleClass');
$rule_class_rs->new({id => 1, name => 'inclusive'})->insert;
$rule_class_rs->new({id => 2, name => 'exclusive'})->insert;
$rule_class_rs->new({id => 3, name => 'multiplicative'})->insert;
$rule_class_rs->new({id => 4, name => 'additive'})->insert;

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
my $layer_id = 1;
my $rule_id = 1; 
my $dataset_id = 1;
my $style_id = 1;

# test a layer that is based on a dataset

test_a_dataset_layer(debug => 0);

# test computing a layer
# there are three methods a layer can be computed

# dataset has a link to style
# layer has a link to style, and possibly a link to dataset
# style = min_value, max_value, classes, color scale, scale (text)
# base class rule = cookie, made, pul, class
# rule that uses dataset = + dataset_id
# rule that uses pul = + pul (is visualization needed?)
# sequential rule = + reduce, op, value, index
#   y = (reduce ? 0 : 1) if x op value
# multiplicative and additive rule = + x_min, x_max, y_min, y_max, weight
#   y = w * (y_min + (x-x_min)*(y_max-y_min)/(x_max-x_min))
#   y = wy_min + (x-x_min)*kw
#   y = wy_min + kw*x - kwx_min
#   y = kw*x + c

test_inclusive_rules(debug => 0);
test_exclusive_rules(debug => 0);
test_multiplicative_rules(debug => 0);
#test_additive_rules(debug => 0);

done_testing();

sub test_additive_rules {
    my %args = @_;
    my $color_scale = $color_scale_rs->single({id=>1}); #grayscale, no meaning here

    my $dataset_1 = make_dataset('Byte', [[1,2,3],[4,5,6],[7,8,9]]);
    my $dataset_2 = make_dataset('Float64', [[1,2,3],[4,5,6],[7,8,9]]);
    
    my $rule_class = $rule_class_rs->single({id=>4}); # additive
    my $layer = make_layer(
        plan_id => 1,
        use_class_id => 2,
        layer_class_id => 4,
        style => {
            color_scale => $color_scale, 
            min => 0, 
            max => 12,
            classes => 4
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset_1 },
                data => { 
                    x_min => 1, x_max => 10, y_min => 0, y_max => 1, weight => 2 
                }
            },{
                based => { dataset_id => $dataset_2 },
                data => { x_min => 1, x_max => 10, y_min => 0, y_max => 1, weight => 1 }
            }
        ]
        );
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
    my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]]);
    
    my $rule_class = $rule_class_rs->single({id=>3}); # multiplicative
    my $layer = make_layer(
        plan_id => 1,
        use_class_id => 2,
        layer_class_id => 3,
        style => {
            color_scale => $color_scale,
            min => 0, 
            max => 2, 
            classes => 3
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset_id },
                data => { x_min => 1, x_max => 200, y_min => 0, y_max => 1, weight => 2 }
            }]
        );
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
    my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]]);
 
    my $rule_class = $rule_class_rs->single({id=>2});
    my $layer = make_layer(
        plan_id => 1,
        use_class_id => 2,
        layer_class_id => 2, 
        style => {
            color_scale => $color_scale,
            min => 0, 
            max => 1, 
            classes => 2
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset_id },
                data => { reduce => 1, op_id => 1, value => 5.0, index => 1 }
            }]
        );
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
    my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]]);
 
    my $rule_class = $rule_class_rs->single({id=>1});
    my $layer = make_layer(
        plan_id => 1,
        use_class_id => 2,
        layer_class_id => 1, 
        style => {
            color_scale => $color_scale,
            min => 0, 
            max => 1, 
            classes => 2
        },
        rule_class => $rule_class,
        rules => [
            {
                based => { dataset_id => $dataset_id },
                data => { reduce => 1, op_id => 1, value => 5.0, index => 1 }
            }]
        );
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
                my $style = {min => 0, max => 120, classes => $classes, color_scale => $color_scale->id};
                my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]], $style);
       
                print Geo::GDAL::Open(Name => $data_dir.$dataset_id.'.tiff')->Band->Piddle if $args{debug};
                
                my $layer = make_layer(plan_id => 0, use_class_id => 0, layer_class_id => $dataset_id);
                my $result = $layer->compute($args{debug});
                my $output = $result->Band->ReadTile;
                
                my $exp;
                if (!defined $classes) {
                    $exp = [[255,1,2],[100,100,100],[0,13,14]];
                } elsif ($classes == 2) {
                    $exp = [[255,0,0],[1,1,1],[0,0,0]];
                } elsif ($classes == 10) {
                    $exp = [[255,0,0],[9,9,9],[0,1,1]];
                }
                my $nclasses = $classes // 'undef';
                my $ok = is_deeply($output, $exp, "dataset with $nclasses classes, $datatype");

                print $result->Band->Piddle() if !$ok && $args{debug};
                
            }
            
        }
    }
}

sub make_layer {
    my %arg = @_;
    if ($arg{use_class_id} > 1) {
        $style_rs->new({
            id => $style_id, 
            color_scale => $arg{style}->{color_scale}->id,
            min => $arg{style}->{min},
            max => $arg{style}->{max},
            classes => $arg{style}->{classes} })->insert;
        $schema->resultset('RuleSystem')->create({
            id => $layer_id, 
            rule_class => $arg{rule_class}->id });
        $schema->resultset('Layer')->create({
            id => $layer_id,
            layer_class => $arg{layer_class_id},
            use => 1,
            rule_system => $layer_id,
            style => $style_id });
        ++$style_id;
        ++$layer_id;
    }
    for my $rule (@{$arg{rules}}) {
        # $args->{rule_class}->id and $rule->{data} must match...
        add_rule($arg{layer_class_id}, $rule->{based}, $rule->{data});
    }
    return SmartSea::Layer->new({
        epsg => $epsg,
        tile => $tile,
        schema => $schema,
        data_dir => $data_dir,
        GDALVectorDataset => undef,
        cookie => '', 
        trail => $arg{plan_id}.'_'.$arg{use_class_id}.'_'.$arg{layer_class_id} });
}

sub add_rule {
    my ($pul, $based, $data) = @_;
    my $rule = {
        id => $rule_id,
        min_value => 0,
        max_value => 1,
        cookie => '',
        made => undef,
        rule_system => $pul
    };
    if ($based->{pul}) {
        $rule->{r_plan} = $based->{pul}{plan_id};
        $rule->{r_use} = $based->{pul}{use_id};
        $rule->{r_layer} = $based->{pul}{layer_id};
    } elsif ($based->{dataset_id}) {
        $rule->{r_dataset} = $based->{dataset_id};
    }
    if ($data->{op_id}) {
        $rule->{op} = $data->{op_id};
        $rule->{value} = $data->{value};
    } else {
        $rule->{value_at_min} = $data->{'y_min'};
        $rule->{value_at_max} = $data->{'y_max'};
        $rule->{min_value} = $data->{x_min};
        $rule->{max_value} = $data->{x_max};
        $rule->{weight} = $data->{weight};
    }
    $rule_rs->new($rule)->insert;
    ++$rule_id;
}

sub make_dataset {
    my ($datatype, $data, $style) = @_;
    # min_value, max_value, classes, style, descr
    $style //= {
        min => undef,
        max => undef,
        classes => undef,
        color_scale => 1
    };
    $style->{id} = $style_id;
    $style_rs->new($style)->insert;
    $dataset_rs->update_or_new(
        {id => $dataset_id,
         name => "dataset_".$dataset_id,
         custodian => '',
         contact => '',
         descr => '',
         data_model => undef,
         is_a_part_of => undef,
         is_derived_from => undef,
         license => undef,
         attribution => '',
         disclaimer => '',
         path => $dataset_id.'.tiff',
         unit => undef,
         style => $style_id
        }, 
        {key => 'primary'})->insert;
    my $test = Geo::GDAL::Driver('GTiff')->Create(
        Name => $data_dir.$dataset_id.".tiff",
        Type => $datatype, 
        Width => $data_wh, 
        Height => $data_wh)->Band;
    $test->Dataset->GeoTransform($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    $test->WriteTile($data);
    ++$style_id;
    ++$dataset_id;
    return $dataset_id-1;
}
