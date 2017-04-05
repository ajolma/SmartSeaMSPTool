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
# trail = plan use layer [rule*]

# may need trail, schema, tile, epsg, data_dir, style
sub new {
    my ($class, $self) = @_;
    my ($plan_id, $use_class_id, $layer_class_id, @rules) = split /_/, $self->{trail} // '';
    #say STDERR "trail: $plan_id, $use_class_id, $layer_class_id, @rules";
    return bless $self, $class unless $layer_class_id;

    if ($use_class_id == 0) {
        $self->{dataset} = $self->{schema}->resultset('Dataset')->single({ id => $layer_class_id });
        $self->{duck} = $self->{dataset};
    } else {
        my $plan = $self->{schema}->resultset('Plan')->single({ id => $plan_id });
        my $use_class = $self->{schema}->resultset('UseClass')->single({ id => $use_class_id });
        my $layer_class = $self->{schema}->resultset('LayerClass')->single({ id => $layer_class_id });
        my $use = $self->{schema}->resultset('Use')->single({
            plan => $plan->id, 
            use_class => $use_class->id });
        my $layer = $self->{schema}->resultset('Layer')->single({
            use => $use->id, 
            layer_class => $layer_class->id });
        $self->{duck} = $layer;

        $self->{rules} = [];
        # rule list is optional, if no rules, then all rules (QGIS plugin does not send any rules)
        if (@rules) {
            for my $id (@rules) {
                # id = 0 is a bail out
                last unless $id;
                
                # there may be default rule and a modified rule denoted with a cookie
                # prefer the one with our cookie
                my $rule;
                for my $r ($self->{schema}->resultset('Rule')->search({ id => $id })) {
                    if ($r->cookie eq $self->{cookie}) {
                        $rule = $r;
                        last;
                    }
                    $rule = $r if $r->cookie eq DEFAULT;
                }
                # maybe we should test $rule->plan and $rule->use?
                # and that the $rule->layer->id is the same?
                push @{$self->{rules}}, $rule;
            }
        } else {
            my %rules;
            for my $rule ($layer->rules) {
                # prefer id/cookie pair to id/default, they have the same id
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
    }

    # todo: if style is defined by a client
    # my $color_scale = $self->{style} // $self->{duck}->style->color_scale->name // 'grayscale';
    # $color_scale =~ s/-/_/g;
    # $color_scale =~ s/\W.*$//g;
    
    $self->{duck}->style->prepare;
    $self->{style} = $self->{duck}->style;

    return bless $self, $class;
}

sub classes {
    my ($self) = @_;
    return $self->{style}->classes;
}

sub class_labels {
    my ($self) = @_;
    return $self->{style}->class_labels // $self->{duck}->descr // '';
}

sub range {
    my ($self) = @_;
    my $min = $self->{style}->min // 0;
    my $max = $self->{style}->max // 1;
    my $unit = $self->{duck}->my_unit ? ' '.$self->{duck}->my_unit->name : '';
    $max = $min if $max < $min;
    return ($min, $max, $unit);
}

sub unit {
    my ($self) = @_;
    my $unit = $self->{duck}->my_unit ? ' '.$self->{duck}->my_unit->name : '';
    return $unit;
}

sub post_process {
    my ($self, $y, $debug) = @_;

    my $result = $self->mask();
    my $mask = $result->Band->Piddle; # 1 = target area, 0 not
    $mask->inplace->setvaltobad(0);

    my $n_classes = $self->{style}->classes // 101;
    $n_classes = 2 if $n_classes == 1;
    
    if ($debug) {
        say STDERR "post processing: classes = $n_classes";
        print STDERR "mask:", $mask;
    }    
        
    $y *= $mask;

    my ($min, $max) = $self->range;
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

    my $method = $self->{duck}->rule_class->name;

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
        $result /= $self->max; # ?? there is $self->{pu}l->additive_max
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
