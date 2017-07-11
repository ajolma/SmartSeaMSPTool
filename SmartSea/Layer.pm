package SmartSea::Layer;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use PDL;
use SmartSea::Core qw(:all);

# a set of rules to create a layer for a use in a plan
# OR
# a dataset
#
# from visualization point of view this is a raster source
# the raster is either continuous data or classed data
# data has min and max (for classed data these are integers)
# (this is in Style)
#
# rules do not have any specific order
# layer name is a sequence of integers separated with non-numbers (a trail)
# trail = 0/1/2 layer_id [rule_id*]

# may need trail, schema, tile, epsg, data_dir, style
sub new {
    my ($class, $self) = @_;
    my ($use_id, $layer_id, @rules) = split /_/, $self->{trail} // '';
    #return bless $self, $class unless $layer_id;

    $use_id //= 0;
    $layer_id //= 0;
    if ($use_id == 0) {
        $self->{dataset} = $self->{schema}->resultset('Dataset')->single({ id => $layer_id });
        croak "Dataset $layer_id does not exist.\n" unless $self->{dataset};
        # min, max, data type should have been obtained with gdalinfo
        $self->{min} = $self->{dataset}->min_value // 0;
        $self->{max} = $self->{dataset}->max_value // 1;
        $self->{min} = $self->{max} if $self->{min} > $self->{max};
        if (my $t = $self->{dataset}->data_type) {
            $self->{data_type} = $t->id; # NumberType, 1 = int, 2 = float
        } else {
            $self->{data_type} = 1;
        }
        my $unit = $self->{dataset}->unit;
        $self->{unit} = defined $unit ? $unit->name : '';
        if ($self->{dataset}->semantics) {
            $self->{labels} = $self->{dataset}->semantics_hash;
        } elsif ($self->{min} == $self->{max}) {
            #$self->{labels} = jotain;
        }
        $self->{duck} = $self->{dataset};
        
    } elsif ($use_id == 1) {
        $self->{duck} = $self->{schema}->resultset('EcosystemComponent')->single({ id => $layer_id });
        croak "Ecosystem component $layer_id does not exist!" unless $self->{duck};
        $self->{min} = 1;
        $self->{max} = 1;
        $self->{data_type} = 1;
        #$self->{labels} = jotain;
        $self->{rules} = [];
        
    } else {
        $self->{layer} = $self->{schema}->resultset('Layer')->single({ id => $layer_id });
        $self->{duck} = $self->{layer};
        croak "Layer $layer_id does not exist!" unless $self->{duck};
        my $class = $self->{layer}->rule_system->rule_class->name;
        if ($class eq 'exclusive' or $class eq 'inclusive') {
            # result is 1 or nodata
            $self->{min} = 1;
            $self->{max} = 1;
            $self->{data_type} = 1;
        } else {
            # result is a floating point value or nodata
            $self->{min} = 0;
            $self->{max} = 1;
            $self->{data_type} = 2;
        }
        $self->{labels} = $self->{layer}->layer_class->semantics_hash;
        $self->{rules} = [];
        # rule list is optional, if no rules, then all rules (QGIS plugin does not send any rules)
        if (@rules) {
            for my $id (@rules) {
                # id = 0 is a bail out
                last unless $id;
                
                # there may be default rule and a modified rule denoted with a cookie
                # prefer the one with our cookie
                my $rule = $self->{schema}->resultset('Rule')->my_find($id, $self->{cookie});
                
                # maybe we should test $rule->plan and $rule->use?
                # and that the $rule->layer->id is the same?
                push @{$self->{rules}}, $rule if $rule;
            }
        }
        
    }
    
    if ($self->{rules} && @{$self->{rules}} == 0) {
        # all rules of this layer, preferring those with given cookie
        my %rules;
        for my $rule ($self->{duck}->rules) {
            if (exists $rules{$rule->id}) {
                $rules{$rule->id} = $rule if $rule->cookie eq $self->{cookie};
            } else {
                $rules{$rule->id} = $rule;
            }
        }
        for my $i (sort {$rules{$a}->name cmp $rules{$b}->name} keys %rules) {
            push @{$self->{rules}}, $rules{$i};
        }
    }

    # color scale may have been set in the constructor, 
    # let it override the one from database
    if ($self->{duck}->style && $self->{style}) {
        my $color_scale = $self->{schema}->resultset('ColorScale')->find({name => $self->{style}});
        $self->{duck}->style->color_scale($color_scale->id) if $color_scale;
    }
    #$self->{debug} = 2;

    return bless $self, $class;
}

sub legend {
    my ($self, $args) = @_;
    $args->{data_type} = $self->{data_type};
    $args->{min} = $self->{min};
    $args->{max} = $self->{max};
    $args->{unit} = $self->{unit};
    $args->{labels} = $self->{labels};
    return $self->{duck}->style->legend($args);
}

sub post_process {
    my ($self, $y) = @_;

    my $result = $self->mask();
    
    my $mask = $result->Band->Piddle; # 1 = target area, 0 not
    $mask->inplace->setvaltobad(0);
        
    $y *= $mask;

    my $style = $self->{duck}->style;

    # if classes == 1, all zero cells get color 0 and non-zero cells get color 1
    $style->prepare($self);

    if ($style->classes == 1) {

        $y->where($y != 0) .= 1;
        
    } else {

        my $k = $style->classes / ($style->max - $style->min);
        my $c = $style->min * $k;
        say STDERR "scale ".$style->min." .. ".$style->max." to ".$style->classes." classes".
            ", k = $k, b = $c" if $self->{debug};
      
        $y = double $y;
        $y = $k*$y - $c;
        $y->where($y > ($style->classes - 1)) .= $style->classes - 1;
        $y->where($y < 0) .= 0;
    }
    
    if ($self->{debug} && $self->{debug} > 1) {
        my @stats = stats($y); # 3 and 4 are min and max
        say STDERR "Result min=$stats[3], max=$stats[4]";
    }

    $y->inplace->setbadtoval(255);
    $result->Band->Piddle(byte $y);
    $result->Band->ColorTable($style->color_scale->color_table($style->classes));
    return $result
}

# todo: move this to rule_system
sub compute {
    my ($self) = @_;

    if ($self->{dataset}) {
        my $result = $self->{dataset}->Piddle($self);
        if ($self->{debug}) {
            my @stats = stats($result); # 3 and 4 are min and max
            say STDERR "Dataset ",$self->{dataset}->name," min=$stats[3], max=$stats[4]";
        }
        return $self->post_process($result);
    }

    my $result = zeroes($self->{tile}->tile);

    my $method = $self->{duck}->rule_system->rule_class->name;
    
    unless ($method eq 'inclusive' || $method eq 'additive') {
        $result += 1;
    }
    # inclusive: start from 0 everywhere and add 1
    
    
    say STDERR "Compute layer, method = $method" if $self->{debug};
    for my $rule (@{$self->{rules}}) {
        $rule->apply($method, $result, $self, $self->{debug});
        if ($self->{debug} && $self->{debug} > 1) {
            my @stats = stats($result); # 3 and 4 are min and max
            my $sum = $result->nelem*$stats[0];
            say STDERR $rule->name,": min=$stats[3], max=$stats[4], sum=$sum";
        }
    }

    return $self->post_process($result);
}

sub mask {
    my $self = shift;
    my $tile = $self->{tile};
    my $dataset = Geo::GDAL::Open($self->{data_dir}.'mask.tiff');
    if ($self->{epsg} == 3067) {
        $dataset = $dataset->Translate( 
            "/vsimem/tmp.tiff", 
            [ -ot => 'Byte', 
              -of => 'GTiff', 
              -r => 'nearest' , 
              -outsize => $tile->tile,
              -projwin => $tile->projwin,
              -a_ullr => $tile->projwin ]);
    } else {
        my $e = $tile->extent;
        $dataset = $dataset->Warp( 
            "/vsimem/tmp.tiff", 
            [ -ot => 'Byte', 
              -of => 'GTiff', 
              -r => 'near' ,
              -t_srs => 'EPSG:'.$self->{epsg},
              -te => @$e,
              -ts => $tile->tile] );
    }
    return $dataset;
}

1;
