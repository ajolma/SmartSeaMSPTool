package SmartSea::Layer;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use PDL;

use SmartSea::Core qw(:all);

# an ordered set of rules to create a layer for a use in a plan
# OR
# a dataset
#
# from visualization point of view this is a raster source
# the raster is either continuous data or classed data
# data has min and max (for classed data these are integers)
#
# the default order of rules is defined in the rules table using "my_index"
# layer name is a sequence of integers separated with non-numbers (a trail)
# trail = plan use layer [rule*]

# may need trail, schema, tile, epsg, data_dir
sub new {
    my ($class, $self) = @_;
    my ($plan_id, $use_id, $layer_id, @rules) = split /\D+/, $self->{trail};
    say STDERR "trail: $plan_id, $use_id, $layer_id, @rules";
    
    return bless $self, $class unless $plan_id;

    if ($plan_id == 0) {
        $self->{dataset} = $self->{schema}->resultset('Dataset')->single({ id => $layer_id });
        $self->{duck} = $self->{dataset};
        return bless $self, $class;
    }
    
    $self->{plan} = $self->{schema}->resultset('Plan')->single({ id => $plan_id });
    $self->{use} = $self->{schema}->resultset('Use')->single({ id => $use_id });
    $self->{layer} = $self->{schema}->resultset('Layer')->single({ id => $layer_id });

    my $plan2use = $self->{schema}->resultset('Plan2Use')->single({
        plan => $self->{plan}->id, 
        use => $self->{use}->id
    });
    $self->{pul} = $self->{schema}->resultset('Plan2Use2Layer')->single({
        plan2use => $plan2use->id, 
        layer => $self->{layer}->id
    });
    $self->{duck} = $self->{pul};

    $self->{rules} = [];
    # rule list is optional
    if (@rules) {
        # rule order is defined by the client in this case
        for my $id (@rules) {
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
        for my $rule ($self->{pul}->rules) {
            # prefer id/cookie pair to id/default, they have the same id
            if (exists $rules{$rule->id}) {
                $rules{$rule->id} = $rule if $rule->cookie eq $self->{cookie};
            } else {
                $rules{$rule->id} = $rule;
            }
        }
        for my $i (sort {$rules{$a}->my_index <=> $rules{$b}->my_index} keys %rules) {
            push @{$self->{rules}}, $rules{$i};
        }
    }
    
    return bless $self, $class;
}

sub classes {
    my ($self) = @_;
    return $self->{duck}->classes;
}

sub range {
    my ($self) = @_;
    my $min = $self->{duck}->min_value // 0;
    my $max = $self->{duck}->max_value // 1;
    my $unit = $self->{duck}->my_unit ? ' '.$self->{duck}->my_unit->name : '';
    $max = $min + 1 if $max - $min == 0;
    return ($min, $max, $unit);
}

sub compute {
    my ($self, $debug) = @_;

    return $self->{dataset}->Piddle($self) if $self->{dataset};

    my $result = zeroes($self->{tile}->tile);

    my $method = $self->{pul}->rule_class->name;

    if ($method =~ /^seq/ || $method =~ /^mult/) {
        $result += 1; # 
    }

    for my $rule (@{$self->{rules}}) {
        if ($debug) {
            my @stats = stats($result); # 3 and 4 are min and max
            say STDERR "result now min=$stats[3], max=$stats[4]";
            my $val = $rule->value // 1;
            say STDERR $rule->as_text," ",$val;
        }
        $rule->apply($method, $result, $self, $debug);
    }

    if ($method =~ /^add/) {
        $result /= $self->max; # ?? there is $self->{pu}l->additive_max
        $result->where($result > 1) .= 1;
    }

    return $result;
}

sub mask {
    my $self = shift;
    my $tile = $self->{tile};
    my $dataset = Geo::GDAL::Open("$self->{data_dir}/mask.tiff");
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
