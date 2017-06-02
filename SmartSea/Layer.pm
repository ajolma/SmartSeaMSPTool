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
    return bless $self, $class unless $layer_id;

    if ($use_id == 0) {
        $self->{dataset} = $self->{schema}->resultset('Dataset')->single({ id => $layer_id });
        croak "Dataset $layer_id does not exist!" unless $self->{dataset};
        $self->{min} = $self->{dataset}->min_value;
        $self->{max} = $self->{dataset}->max_value;
        $self->{min} = 0 if $self->{min} == $self->{max}; # hack, probably nodata/1 type raster
        my $unit = $self->{dataset}->unit;
        $self->{unit} = $unit->name if defined $unit;
        $self->{labels} = $self->{dataset}->class_semantics;
        if ($self->{dataset}->class_semantics) {
            $self->{classes} = $self->{dataset}->max_value - $self->{dataset}->min_value + 1;
        }
        $self->{duck} = $self->{dataset};
        
    } elsif ($use_id == 1) {
        $self->{duck} = $self->{schema}->resultset('EcosystemComponent')->single({ id => $layer_id });
        croak "Ecosystem component $layer_id does not exist!" unless $self->{duck};
        $self->{rules} = [];
        
    } else {
        $self->{layer} = $self->{schema}->resultset('Layer')->single({ id => $layer_id });
        $self->{duck} = $self->{layer};
        croak "Layer $layer_id does not exist!" unless $self->{duck};
        my $class = $self->{layer}->rule_system->rule_class->name;
        if ($class eq 'exclusive' or $class eq 'inclusive') {
            $self->{min} = 0;
            $self->{max} = 1;
            $self->{classes} = 1;
            $self->{labels} = 'valid';
        }
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

    # todo: if style is defined by a client
    # my $color_scale = $self->{style} // $self->{duck}->style->color_scale->name // 'grayscale';
    # $color_scale =~ s/-/_/g;
    # $color_scale =~ s/\W.*$//g;

    # min, max, classes get default values from data etc
    # these are propagated to style but style can override them
    # then style values are propagated back here

    $self->{unit} //= '';
    $self->{style} = $self->{duck}->style;
    $self->{style}->prepare($self);
    $self->{min} = $self->{style}->min;
    $self->{max} = $self->{style}->max;
    $self->{classes} = $self->{style}->classes;    
    
    return bless $self, $class;
}

sub legend {
    my ($self, $args) = @_;
    $args->{unit} //= $self->{unit};
    $args->{labels} //= $self->{labels};
    return $self->{style}->legend($args);
}

sub post_process {
    my ($self, $y, $debug) = @_;

    my $result = $self->mask();
    my $mask = $result->Band->Piddle; # 1 = target area, 0 not
    $mask->inplace->setvaltobad(0);

    my $n_classes = $self->{classes};
    
    if ($debug) {
        say STDERR "post processing: classes = $n_classes";
        print STDERR "mask:", $mask;
    }    
        
    $y *= $mask;

    my $min = $self->{min};
    my $max = $self->{max};
    if ($debug) {
        say STDERR "scale to $min .. $max";
    }    
    
    # scale and bound to min .. max => 0 .. $nc-1
    $y = double $y;
    my $k = $n_classes/($max-$min);
    my $b = $min * $k;
    $y = $k*$y - $b;
    $y->where($y > ($n_classes-1)) .= $n_classes-1;
    $y->where($y < 0) .= 0;

    $y->inplace->setbadtoval(255);
    $result->Band->Piddle(byte $y);
    $result->Band->ColorTable($self->{style}{color_table});
    return $result
}

sub compute {
    my ($self, $debug) = @_;

    if ($self->{dataset}) {
        my $result = $self->{dataset}->Piddle($self);
        if ($debug) {
            my @stats = stats($result); # 3 and 4 are min and max
            say STDERR "Dataset: ",$self->{dataset}->name;
            say STDERR "  result min=$stats[3], max=$stats[4]";
        }
        return $self->post_process($result, $debug);
    }

    my $result = zeroes($self->{tile}->tile);

    my $method = $self->{duck}->rule_system->rule_class->name;

    unless ($method =~ /^incl/) {
        $result += 1;
    }
    # inclusive: start from 0 everywhere and add 1
    
    if ($debug) {
        #say STDERR "Compute: ",$plan->name,' ',$use_class->name,' ',$layer_class->name;
        my @stats = stats($result); # 3 and 4 are min and max
        say STDERR "  result min=$stats[3], max=$stats[4]";
    }
    for my $rule (@{$self->{rules}}) {
        if ($debug) {
            my $val = $rule->value // 1;
            say STDERR "apply: ",$rule->name," ",$val;
        }
        $rule->apply($method, $result, $self, $debug);
        if ($debug) {
            my @stats = stats($result); # 3 and 4 are min and max
            say STDERR "  result min=$stats[3], max=$stats[4]";
        }
    }
    if ($debug) {
        if ($debug > 1) {
            print STDERR $result;
        }
        say STDERR "End compute";
    }

    if ($method =~ /^add/) {
        say STDERR "$self";
        $result /= $self->max; # ?? there is $self->{pu}l->additive_max
        say STDERR "$result";
        $result->where($result > 1) .= 1;
    }

    return $self->post_process($result, $debug);
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
