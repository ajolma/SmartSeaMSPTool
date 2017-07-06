package SmartSea::Schema::Result::Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use Carp;
use PDL;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Layer;

my @columns = (
    id           => {},
    cookie       => {},
    made         => {},
    rule_system  => { is_foreign_key => 1, source => 'RuleSystem', not_null => 1 },
    layer        => { is_foreign_key => 1, source => 'Layer' },
    dataset      => { is_foreign_key => 1, source => 'Dataset',    not_null => 1, objs => {path => {'!=',undef}} },
    op           => { is_foreign_key => 1, source => 'Op'  },
    value        => { data_type => 'text', type => 'double', empty_is_default => 1 },
    min_value    => { data_type => 'text', type => 'double', empty_is_default => 1 },
    max_value    => { data_type => 'text', type => 'double', empty_is_default => 1 },
    value_at_min => { data_type => 'text', type => 'double', empty_is_default => 1 },
    value_at_max => { data_type => 'text', type => 'double', empty_is_default => 1 },
    weight       => { data_type => 'text', type => 'double', empty_is_default => 1 }
    );

# how to compute the weighted value for x:
# w_r = weight * (value_at_min + (x - min_value)*(value_at_max - value_at_min)/(max_value - min_value))
# value_at_min and value_at_max are between 0 and 1
# x, min_value and max_value are in data units
# 
# to combine multiple rules, multiply
# suitability = multiply_all(w_r_1 ... w_r_n)

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

sub my_columns_info {
    my ($self, $parent) = @_;
    my %my_info;
    my $class = '';
    $class = $parent->rule_system->rule_class->name if $parent && $parent->rule_system;
    for my $col ($self->columns) {
        if ($parent) {
            if ($class eq 'additive' or $class eq 'multiplicative') {
                next if $col eq 'op';
                next if $col eq 'value';
            } else {
                next if $col eq 'min_value';
                next if $col eq 'max_value';
                next if $col eq 'value_at_min';
                next if $col eq 'value_at_max';
                next if $col eq 'weight';
            }
        }
        my %info = (%{$self->column_info($col)});
        if (blessed($self) && $col eq 'value') {
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
                    %info = (
                        is_foreign_key => 1,
                        objs => \@objs,
                        values => \@values
                        );
                }
            }
        }
        $my_info{$col} = \%info;
    }
    return \%my_info;
}

sub column_values_from_context {
    my ($self, $parent) = @_;
    return {rule_system => $parent->rule_system->id} if ref $parent eq 'SmartSea::Schema::Result::Layer';
    return {rule_system => $parent->distribution->id} if ref $parent eq 'SmartSea::Schema::Result::EcosystemComponent';
    return {};
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

    my $class = $self->rule_system->rule_class->name;

    if ($class eq 'exclusive' || $class eq 'inclusive') {
        my $sign = $class eq 'exclusive' ? '-' : '+';
        my $n = $criteria->classes;
        say STDERR "Rule ".$self->id." is based on dataset without data type!" unless defined $n;
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
            return "$sign if ".$criteria->name." $op $value";
        }
    }
    
    my $x_min = $self->min_value;
    my $x_max = $self->max_value;
    my $y_min = $self->value_at_min;
    my $y_max = $self->value_at_max;
    my $w = $self->weight;
    
    if ($class eq 'additive') {
        return "+ $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($criteria - $x_min)";
    } elsif ($class eq 'multiplicative') {
        return "* $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($criteria - $x_min)";
    }
}

sub tree {
    my $self = shift;
    return {
        id => $self->id, 
        #layer => undef,
        op => $self->op->name,
        value => $self->value+0,
        dataset => $self->dataset ? $self->dataset->id : undef,
        #min_value => $self->min_value,
        #max_value => $self->max_value
    };
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
    my ($self, $method, $y, $rules, $debug) = @_;

    # the operand (x)
    my $x = $self->operand($rules);
    return unless defined $x;
    
    if ($debug) {
        if ($debug > 1) {
            print STDERR $x;
        } else {
            my @stats = stats($x); # 3 and 4 are min and max
            say STDERR "  operand min=$stats[3], max=$stats[4]";
        }
    }

    if ($method =~ /^incl/ || $method =~ /^excl/) {

        my $op = $self->op->name;
        my $value = $self->value;

        my $value_if_true = $method =~ /^incl/ ? 1 : 0;

        if ($op eq '<=')    { $y->where($x <= $value) .= $value_if_true; } 
        elsif ($op eq '<')  { $y->where($x <  $value) .= $value_if_true; }
        elsif ($op eq '>=') { $y->where($x >= $value) .= $value_if_true; }
        elsif ($op eq '>')  { $y->where($x >  $value) .= $value_if_true; }
        elsif ($op eq '==') { $y->where($x == $value) .= $value_if_true; }

    } else {
        
        my $x_min = $self->min_value;
        my $x_max = $self->max_value;
        my $y_min = $self->value_at_min // 0;
        my $y_max = $self->value_at_max // 1;
        my $w = $self->weight;

        my $kw = $w * ($y_max-$y_min)/($x_max-$x_min);
        my $c = $w * $y_min - $kw * $x_min;

        # todo: limit $x to min max

        if ($method =~ /^mult/) {
            
            $y *= $kw * $x + $c;
            
        } elsif ($method =~ /^add/) {
            
            $y += $kw * $x + $c;
            
        }
        
    }
}

sub operand {
    my ($self, $rules) = @_;
    
    if ($self->layer) {
        
        # not tested!
        # how to avoid circular references?
        
        return $self->layer->rule_system->compute;
        
    } elsif ($self->dataset) {
        return $self->dataset->Piddle($rules);
        
    }
    
    return undef;
}

1;
