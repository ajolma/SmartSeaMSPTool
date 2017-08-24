package SmartSea::Schema::Result::Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core Exporter/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use Carp;
use PDL;
use SmartSea::Schema::Result::RuleClass qw(:all);
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Layer;

# @columns go inside DBIx as columns info
# DBIx recognizes some keys and adds some of its own
# we also mess with the contents of the info, both on schema and on object level
# on schema level we may add semantics, and columns keys
# on object level we may add not_used, and value keys
# that means the columns info is valid only for one object at a time
my @columns = (
    id           => {},
    cookie       => { system_column => 1 }, # empty or cookie
    made         => { system_column => 1 },
    rule_system  => { is_foreign_key => 1, source => 'RuleSystem', not_null => 1 },
    layer        => { is_foreign_key => 1, source => 'Layer' },
    dataset      => { is_foreign_key => 1, source => 'Dataset',    not_null => 1, objs => {path => {'!=',undef}} },
    op           => { is_foreign_key => 1, source => 'Op', has_default => 1  },
    value        => { data_type => 'double', has_default => 1 },
    min_value    => { data_type => 'double', has_default => 1 },
    max_value    => { data_type => 'double', has_default => 1 },
    value_at_min => { data_type => 'double', has_default => 1 },
    value_at_max => { data_type => 'double', has_default => 1 },
    weight       => { data_type => 'double', has_default => 1 },
    boxcar       => { data_type => 'boolean', default => 1, has_default => 1 },
    boxcar_x0    => { data_type => 'double', has_default => 1 },
    boxcar_x1    => { data_type => 'double', has_default => 1 },
    boxcar_x2    => { data_type => 'double', has_default => 1 },
    boxcar_x3    => { data_type => 'double', has_default => 1 },
    node_id      => { data_type => 'text' },
    state_offset => { data_type => 'integer', has_default => 1 },
    );

__PACKAGE__->table('rules');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id', 'cookie');

__PACKAGE__->belongs_to(rule_system => 'SmartSea::Schema::Result::RuleSystem');
__PACKAGE__->belongs_to(layer => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(dataset => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(op => 'SmartSea::Schema::Result::Op');

sub criteria {
    my $self = shift;
    return $self->dataset ? $self->dataset : ($self->layer ? $self->layer : undef);
}

sub columns_info {
    my ($self, $colnames, $parent) = @_;
    my $info = $self->SUPER::columns_info($colnames);
    for my $col ($self->columns) {
        delete $info->{$col}{not_used};
        delete $info->{$col}{semantics};
    }
    my $class;
    if (ref $self) {
        $class = $self->rule_system->rule_class->id;
    } elsif ($parent) {
        if ($parent->can('rule_class')) {
            $class = $parent->rule_class->id;
        } elsif ($parent->can('distribution')) {
            $class = $parent->distribution->rule_class->id;
        } elsif ($parent->can('rule_system')) {
            $class = $parent->rule_system->rule_class->id;
        }
    }
    return $info unless $class;
    my ($clusive, $tive, $boxcar, $bayesian);
    if ($class == EXCLUSIVE_RULE || $class == INCLUSIVE_RULE) {
        $clusive = 1;
    } elsif ($class == MULTIPLICATIVE_RULE || $class == ADDITIVE_RULE) {
        $tive = 1;
    } elsif ($class == BOXCAR_RULE) {
        $boxcar = 1;
    } elsif ($class == BAYESIAN_NETWORK_RULE) {
        $bayesian = 1;
    } else {
        #can't confess before tests are fixed to not use unknown rule classes
        #confess "Unknown rule class: $class";
    }
    for my $col ($self->columns) {
        if ($col eq 'op') {
            $info->{$col}{not_used} = 1 unless $clusive;
        } elsif ($col eq 'value') {
            unless ($clusive) {
                $info->{$col}{not_used} = 1;
            } elsif (blessed($self)) {
                my $criteria = $self->criteria;
                if ($criteria) {
                    my $semantics = $criteria->semantics_hash;
                    if ($semantics) {
                        my @objs;
                        my @values;
                        for my $value (keys %$semantics) {
                            push @objs, {id => $value, name => $semantics->{$value}};
                            push @values, $value;
                        }
                        $info->{$col}{semantics}{is_foreign_key} = 1;
                        $info->{$col}{semantics}{objs} = \@objs;
                        $info->{$col}{semantics}{values} = \@values;
                    }
                }
            }
        } elsif ($col eq 'min_value' || $col eq 'max_value' || 
                 $col eq 'value_at_min' || $col eq 'value_at_max') {
            $info->{$col}{not_used} = 1 unless $tive;
        } elsif ($col eq 'weight') {
            $info->{$col}{not_used} = 1 unless $tive || $boxcar;
        } elsif ($col =~ /^boxcar/) {
            $info->{$col}{not_used} = 1 unless $boxcar;
        } elsif ($col eq 'node_id') {
            $info->{$col}{not_used} = 1 unless $bayesian;
        } elsif ($col eq 'state_offset') {
            $info->{$col}{not_used} = 1 unless $bayesian;
        }
    }
    return $info;
}

sub is_ok {
    my ($self, $col_data) = @_;
    my $dataset;
    my $layer;
    if (ref $self) {
        if ($self->dataset) {
            if (exists $col_data->{dataset}) {
                $dataset = $col_data->{dataset};
            } else {
                $dataset = 1;
            }
        } else {
            if (exists $col_data->{layer}) {
                $layer = $col_data->{layer};
            } else {
                $layer = 1;
            }
        }
    } else {
        $dataset = $col_data->{dataset} if exists $col_data->{dataset};
        $layer = $col_data->{layer} if exists $col_data->{layer};
    }
    return "Rule must be based either on a layer or on a dataset." unless $dataset xor $layer;
    return undef;
}

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my ($self, %args) = @_;

    my $criteria = $self->criteria;
    croak "Rule ".$self->id." does not have criteria!" unless $criteria;

    my $class = $self->rule_system->rule_class->id;

    if ($class == EXCLUSIVE_RULE || $class == INCLUSIVE_RULE) {
        my $sign = $class == EXCLUSIVE_RULE ? '-' : '+';
        my $n = $criteria->classes;
        say STDERR "Rule ".$self->id.": dataset ".$criteria->name." lacks data type!" unless defined $n;
        $n //= 1;
        return "$sign if ".$criteria->name if $n == 1;
        my $op = $self->op->name // '';
        my $value = $self->value // '';
        say STDERR "Rule ".$self->id." does not have a threshold!" if $op eq '' || $value eq '';
        my $semantics = $criteria->semantics_hash;
        if ($semantics) {
            if (defined $semantics->{$value}) {
                $value = $semantics->{$value};
            } elsif ($value ne '') {
                say STDERR "Value $value does not have a meaning in rule ".$self->id."!";
            }
        }
        return "$sign if ".$criteria->name." $op $value";
        
    } elsif ($class == MULTIPLICATIVE_RULE || $class == ADDITIVE_RULE) {
        my $x_min = $self->min_value;
        my $x_max = $self->max_value;
        my $y_min = $self->value_at_min;
        my $y_max = $self->value_at_max;
        my $w = $self->weight;
        my $name = $criteria->name;
        if ($class == ADDITIVE_RULE) {
            return "+ $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($name - $x_min)";
        } else {
            return "* $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($name - $x_min)";
        }
        
    } elsif ($class == BOXCAR_RULE) {
        my $fct = $self->boxcar_x0.', '.$self->boxcar_x1.', '.$self->boxcar_x2.', '.$self->boxcar_x3;
        $fct .= ' weight '.$self->weight;
        return "Normal with turning points at ".$fct if $self->boxcar;
        return "Inverted with turning points at ".$fct;

    } elsif ($class == BAYESIAN_NETWORK_RULE) {
        return ($self->node_id//'').' offset='.$self->state_offset;
        
    } else {
        #croak "Unknown rule class: ".$self->rule_system->rule_class->name;
    }
}

sub read {
    my $self = shift;
    my $class = $self->rule_system->rule_class->id;
    my $clusive = $class == EXCLUSIVE_RULE || $class == INCLUSIVE_RULE;
    my $columns = $self->columns_info;
    my $retval = { id => $self->id };
    $retval->{layer} = $self->layer->id if $self->layer;
    $retval->{dataset} = $self->dataset->id if $self->dataset;
    $retval->{op} = $self->op->name if $clusive;
    for my $key (keys %$columns) {
        my $meta = $columns->{$key};
        next if $meta->{not_used};
        next if $meta->{system_column};
        next if $meta->{is_foreign_key};
        next if exists $retval->{$key};
        $retval->{$key} = $self->$key;
        $retval->{$key} += 0 if data_type_is_numeric($meta->{data_type});
    }
    return $retval;
}

# this is needed by modify request
sub values {
    my ($self) = @_;
    my %values = (id => $self->id, rule_system => $self->rule_system->id);
    for my $col ($self->columns) {
        my $info = $self->column_info($col);
        if ($info->{is_foreign_key}) {
            my $foreign = $self->$col;
            $values{$col} = $self->$col->id if $foreign;
        } else {
            $values{$col} = $self->$col;
        }
    }
    return \%values;
}

sub apply {
    my ($self, $y, $args) = @_;

    my $class = $self->rule_system->rule_class->id;
    
    # y is a piddle with values so far
    # after this method y has this rule applied
    #
    # in the beginning, y = 0 for inclusive & additive rule systems
    # and y = 1 for exclusive and multiplicative rule systems
    #
    # operand (x) is a piddle from a dataset or from another layer
    # x may contain 'bad' values, i.e. cells with no value (not known, 
    # outside of study are, ...)
    #
    # exclusive and inclusive rules compare x to rule value
    # using rule comparison operator 
    #
    # exclusive rules set those cells to 0 where the comparison is true
    # inclusive rules set those cells to 1 where the comparison is true
    #
    # additive rules add the scaled and weighted x to the cell value
    # multiplicative rules multiply the cell value with the scaled and weighted x
    #
    # scaling and weighing of x:
    #
    # k = (y_max - y_min) / (x_max - x_min)
    # c = y_min - k * x_min
    # x' = w * (k * x + c)
    #
    # boxcar rule adds w * f(x) to y
    # f(x) is a relaxed boxcar function, defined as
    # y = y0 if x < x[0] or x > x[n-1]
    # y = (x-x[i])/(x[i+1]-x[i]) otherwise
    # y0 is 0 or 1
    # i = 0..n-1, n = 4
    # the maximum y becomes thus sum of the rule weights
    #

    # the operand (x)
    my $x = $self->operand($args);
    return unless defined $x;
    
    if ($class == EXCLUSIVE_RULE || $class == INCLUSIVE_RULE) {

        my $op = $self->op->name;
        my $value = $self->value;

        my $value_if_true = $class == INCLUSIVE_RULE ? 1 : 0;

        if ($op eq '<=')    { $y->where($x <= $value) .= $value_if_true; } 
        elsif ($op eq '<')  { $y->where($x <  $value) .= $value_if_true; }
        elsif ($op eq '>=') { $y->where($x >= $value) .= $value_if_true; }
        elsif ($op eq '>')  { $y->where($x >  $value) .= $value_if_true; }
        elsif ($op eq '==') { $y->where($x == $value) .= $value_if_true; }
        elsif ($op eq 'NOT'){ $y->where($x != $value) .= $value_if_true; }

    } elsif ($class == MULTIPLICATIVE_RULE || $class == ADDITIVE_RULE) {
        
        my $x_min = $self->min_value;
        my $x_max = $self->max_value;
        my $y_min = $self->value_at_min;
        my $y_max = $self->value_at_max;
        my $w = $self->weight;

        my $kw = $w * ($y_max-$y_min)/($x_max-$x_min);
        my $c = $w * $y_min - $kw * $x_min;

        # todo: limit $x to min max

        #print "before rule ".$self->id,"\n",$y;

        if ($class == MULTIPLICATIVE_RULE) {
            
            $y *= $kw * $x + $c;
            
        } else {
            
            $y += $kw * $x + $c;
            
        }

        #print "after rule ".$self->id,"\n",$y;

    } elsif ($class == BOXCAR_RULE) {

        my $boxcar = $self->boxcar;
        my $x0 = $self->boxcar_x0;
        my $x1 = $self->boxcar_x1;
        my $x2 = $self->boxcar_x2;
        my $x3 = $self->boxcar_x3;
        my $w = $self->weight;

        if ($boxcar) {
            my $divisor = $x1 - $x0;
            my $xleft;
            if ($divisor != 0) {
                $xleft = ($x - $x0) / $divisor;
                $xleft *= ($xleft >= 0) + ($xleft <= 1) - 1;
            } else {
                $xleft = 0;
            }
            
            #print "left ",$xleft;

            $divisor = $x3 - $x2;
            my $xright;
            if ($divisor != 0) {
                $xright = ($x3 - $x) / $divisor;
                $xright *= ($xright >= 0) + ($xright <= 1) - 1;
            } else {
                $xright = 0;
            }
            
            #print "right ",$xright;

            my $xmiddle = ($x >= $x1) + ($x <= $x2) - 1;

            #print "middle ",$xmiddle;

            $y += $w * ($xleft + $xmiddle + $xright);
            
        } else {
            my $divisor = $x1 - $x0;
            my $xleft;
            if ($divisor != 0) {
                $xleft = ($x1 - $x) / $divisor;
                $xleft *= ($xleft >= 0) + ($xleft <= 1) - 1;
                $xleft += $x < $x0;
            } else {
                $xleft = $x <= $x0;
            }
            
            #print "left ",$xleft;

            $divisor = $x3 - $x2;
            my $xright;
            if ($divisor != 0) {
                $xright = ($x - $x2) / $divisor;
                $xright *= ($xright >= 0) + ($xright <= 1) - 1;
                $xright += $x > $x3;
            } else {
                $xright = $x >= $x3;
            }
            
            #print "right ",$xright;

            $y += $w * ($xleft + $xright);
            
        }
        
    } else {
        #croak "Unknown rule class: ".$self->rule_system->rule_class->name;
    }
    
    if ($args->{debug} && $args->{debug} > 1) {
        my @stats = stats($x); # 3 and 4 are min and max
        my @stats2 = stats($y); # 3 and 4 are min and max
        say STDERR 
            "Rule ",$self->id," class ",$class,
            " operand=[$stats[3]..$stats[4]] result=[$stats2[3]..$stats2[4]]";
        
    }
}

sub operand {
    my ($self, $args) = @_;
    
    if ($self->layer) {
        
        # not tested!
        # how to avoid circular references?
        
        return $self->layer->rule_system->compute;
        
    } elsif ($self->dataset) {
        
        return $self->dataset->Band($args)->Piddle;
        
    } else {

        croak "Missing layer or dataset in rule ".$self->id;

    }
    
    return undef;
}

1;
