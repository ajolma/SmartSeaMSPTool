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
for my $i (1..3) {
    $schema->resultset('Layer')->new({id => $i, name => 'layer_'.$i})->insert;
}

$schema->resultset('Plan')->single({id => 1})
    ->create_related('plan2use', {id => 1, plan => 1, 'use' => 1});

my $pul_id = 1; # sequence
my $rule_id = 1; ## sequence
my $dataset_id = 1;

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

# dataset + visualization = ?
# pul + visualization =
# visualization = min_value, max_value, classes, style, descr
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

test_sequential_rules(debug => 0);
test_multiplicative_rules(debug => 0);
#test_additive_rules(debug => 2);

done_testing();

sub test_additive_rules {
    my %args = @_;
    my $style = $style_rs->single({id=>1}); #grayscale, no meaning here

    my $dataset_1 = make_dataset('Byte', [[1,2,3],[4,5,6],[7,8,9]]);
    my $dataset_2 = make_dataset('Float64', [[1,2,3],[4,5,6],[7,8,9]]);
    
    my $rule_class = $rule_class_rs->single({id=>3}); # multiplicative
    my $layer = make_layer(
        1,1,3, 
        {
            style => $style, 
            rule_class => $rule_class, 
            min_value => 0, 
            max_value => 12,
            classes => 4
        },[{
            based => { dataset_id => $dataset_1 },
            data => { x_min => 1, x_max => 10, y_min => 0, y_max => 1, weight => 2 }
           },{
            based => { dataset_id => $dataset_2 },
            data => { x_min => 1, x_max => 10, y_min => 0, y_max => 1, weight => 1 }
           }]
        );
    my $result = $layer->compute($args{debug});
    
    my $output = $result->Band->ReadTile;
    my $exp = [[255,0,0],[1,2,2],[0,0,0]];
    my $ok = is_deeply($output, $exp, $rule_class->name());
    print $result->Band->Piddle() if !$ok && $args{debug};

}

sub test_multiplicative_rules {
    my %args = @_;
    my $style = $style_rs->single({id=>1}); #grayscale, no meaning here

    my $datatype = 'Int32';
    my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]]);
    
    my $rule_class = $rule_class_rs->single({id=>2}); # multiplicative
    my $layer = make_layer(
        1,1,2, 
        {
            style => $style, 
            rule_class => $rule_class, 
            min_value => 0, 
            max_value => 2, 
            classes => 3
        },[{
            based => { dataset_id => $dataset_id },
            data => { x_min => 1, x_max => 200, y_min => 0, y_max => 1, weight => 2 }
           }]
        );
    my $result = $layer->compute($args{debug});
    
    my $output = $result->Band->ReadTile;
    my $exp = [[255,0,0],[1,2,2],[0,0,0]];
    my $ok = is_deeply($output, $exp, $rule_class->name()." rules with dataset of $datatype");
    print $result->Band->Piddle() if !$ok && $args{debug};

}

sub test_sequential_rules {
    my %args = @_;
    my $style = $style_rs->single({id=>1}); #grayscale, no meaning here
    
    my $datatype = 'Int32';
    my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]]);
 
    my $rule_class = $rule_class_rs->single({id=>1}); # sequential
    my $layer = make_layer(
        1,1,1, 
        {
            style => $style, 
            rule_class => $rule_class, 
            min_value => 0, 
            max_value => 1, 
            classes => 2
        },[{
            based => { dataset_id => $dataset_id },
            data => { reduce => 1, op_id => 1, value => 5.0, index => 1 }
           }]
        );
    my $result = $layer->compute($args{debug});

    my $output = $result->Band->ReadTile;
    my $exp = [[255,1,1],[0,0,0],[1,0,0]];
    my $ok = is_deeply($output, $exp, $rule_class->name()." rules with dataset of $datatype");
    print $result->Band->Piddle() if !$ok && $args{debug};
}

sub test_a_dataset_layer {
    my %args = @_;
    for my $datatype (qw/Byte Int16 Int32 Float32 Float64/) {
        for my $style ($style_rs->all) {
            for my $classes (undef, 2, 10) {
                my $v = {range => [0,120], classes => $classes, style_id => $style->id};
                my $dataset_id = make_dataset($datatype, [[1,2,3],[150,160,180],[0,16,17]], $v);
       
                print Geo::GDAL::Open(Name => $data_dir.$dataset_id.'.tiff')->Band->Piddle if $args{debug};
                
                my $layer = make_layer(0,0,$dataset_id);
                my $result = $layer->compute($args{debug});
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
                my $ok = is_deeply($output, $exp, "dataset with $nclasses classes, $datatype");

                print $result->Band->Piddle() if !$ok && $args{debug};
                
            }
            
        }
    }
}

sub make_layer {
    my ($plan_id, $use_id, $layer_id, $args, $rules) = @_;
    if ($use_id > 0) {
        $schema->resultset('Layer')->single({id => $layer_id})->create_related
            ( 'plan2use2layer', 
              {
                  id => $pul_id,
                  plan2use => 1,
                  rule_class => $args->{rule_class}->id,
                  style => $args->{style}->id,
                  min_value => $args->{min_value},
                  max_value => $args->{max_value},
                  classes => $args->{classes}
              });
    }
    for my $rule (@$rules) {
        # $args->{rule_class}->id and $rule->{data} must match...
        add_rule($pul_id, $rule->{based}, $rule->{data});
    }
    ++$pul_id;
    return SmartSea::Layer->new({
        epsg => $epsg,
        tile => $tile,
        schema => $schema,
        data_dir => $data_dir,
        GDALVectorDataset => undef,
        cookie => '', 
        trail => $plan_id.'_'.$use_id.'_'.$layer_id});
}

sub add_rule {
    my ($pul, $based, $data) = @_;
    my $rule = {
        id => $rule_id,
        min_value => 0,
        max_value => 1,
        cookie => '',
        made => undef,
        plan2use2layer => $pul
    };
    if ($based->{pul}) {
        $rule->{r_plan} = $based->{pul}{plan_id};
        $rule->{r_use} = $based->{pul}{use_id};
        $rule->{r_layer} = $based->{pul}{layer_id};
    } elsif ($based->{dataset_id}) {
        $rule->{r_dataset} = $based->{dataset_id};
    }
    if ($data->{op_id}) {
        $rule->{reduce} = $data->{reduce};
        $rule->{op} = $data->{op_id};
        $rule->{value} = $data->{value};
        $rule->{my_index} = $data->{index};
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
    my ($datatype, $data, $visualization) = @_;
    # min_value, max_value, classes, style, descr
    $visualization //= {
        range => [undef,undef],
        classes => undef,
        style_id => 1,
        descr => undef
    };
    $dataset_rs->update_or_new(
        {id => $dataset_id,
         name => "dataset_".$dataset_id,
         custodian => '',
         contact => '',
         descr => $visualization->{descr},
         data_model => undef,
         is_a_part_of => undef,
         is_derived_from => undef,
         license => undef,
         attribution => '',
         disclaimer => '',
         path => $dataset_id.'.tiff',
         unit => undef,
         min_value => $visualization->{range}[0],
         max_value => $visualization->{range}[1],
         classes => $visualization->{classes},
         style => $visualization->{style_id}
        }, 
        {key => 'primary'})->insert;
    my $test = Geo::GDAL::Driver('GTiff')->Create(
        Name => $data_dir.$dataset_id.".tiff",
        Type => $datatype, 
        Width => $data_wh, 
        Height => $data_wh)->Band;
    $test->Dataset->GeoTransform($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    $test->WriteTile($data);
    ++$dataset_id;
    return $dataset_id-1;
}
