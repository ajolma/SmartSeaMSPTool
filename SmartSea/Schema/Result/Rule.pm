package SmartSea::Schema::Result::Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use PDL;

use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Layer;

my %attributes = (
    #layer =>        { i => 1,  input => 'lookup', class => 'Layer',   allow_null => 0 },
    r_layer =>      { i => 7,  input => 'lookup', class => 'Layer',   allow_null => 1 },
    r_dataset =>    { i => 8,  input => 'lookup', class => 'Dataset', allow_null => 1, objs => {path => {'!=',undef}} },
    op =>           { i => 9,  input => 'lookup', class => 'Op'  },
    value =>        { i => 10, input => 'text', type => 'double', empty_is_default => 1 },
    min_value =>    { i => 11, input => 'text', type => 'double', empty_is_default => 1 },
    max_value =>    { i => 12, input => 'text', type => 'double', empty_is_default => 1 },
    value_type =>   { i => 14, input => 'lookup', class => 'NumberType' },
    value_at_min => { i => 15, input => 'text', type => 'double', empty_is_default => 1 },
    value_at_max => { i => 16, input => 'text', type => 'double', empty_is_default => 1 },
    weight =>       { i => 17, input => 'text', type => 'double', empty_is_default => 1 }
    );

# how to compute the weighted value for x:
# w_r = weight * (value_at_min + (x - min_value)*(value_at_max - value_at_min)/(max_value - min_value))
# value_at_min and value_at_max are between 0 and 1
# x, min_value and max_value are in data units
# 
# to combine multiple rules, multiply
# suitability = multiply_all(w_r_1 ... w_r_n)

__PACKAGE__->table('rules');
__PACKAGE__->add_columns('id', 'cookie', 'made', 'layer', keys %attributes);
__PACKAGE__->set_primary_key('id', 'cookie');

__PACKAGE__->belongs_to(layer => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(r_layer => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(r_dataset => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(op => 'SmartSea::Schema::Result::Op');

sub attributes {
    my ($self, $parent) = @_;
    return \%attributes unless $parent;
    my %a = %attributes;
    my $class = $parent->rule_class->name;
    if ($class eq 'additive' or $class eq 'multiplicative') {
        delete $a{op};
        delete $a{value};
        delete $a{value_type};
    } else {
        delete $a{min_value};
        delete $a{max_value};
        delete $a{value_at_min};
        delete $a{value_at_max};
        delete $a{weight};
    }
    return \%a;
}

sub is_ok {
    my ($self, $col_data) = @_;
    return "Rule must be based either on a layer or on a dataset." if 
        (!defined($col_data->{r_dataset}) && !defined($col_data->{r_layer})) ||
        (defined($col_data->{r_dataset}) && defined($col_data->{r_layer}));
    return undef;
}

sub order_by {
    return {-asc => 'id'};
}

sub class_name {
    my ($self, $parent) = @_;
    #say STDERR "class name for rule: @_";
    return 'Rule' unless $self && $parent;
    my $class = $parent->rule_class->name;
    return "$class Rule";
}

sub name_with_parent {
    my ($self, $parent) = @_;
    my $class = $parent->rule_class->name;

    my $x = $self->r_layer ? 
        $self->r_layer->name : 
        ($self->r_dataset ? $self->r_dataset->name : 'undefined');
    
    my $op = $self->op->name;
    my $value = $self->value;
    my $x_min = $self->min_value;
    my $x_max = $self->max_value;
    my $y_min = $self->value_at_min;
    my $y_max = $self->value_at_max;
    my $w = $self->weight;
    
    if ($class eq 'additive') {
        return "+ $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($x - $x_min)";
    } elsif ($class eq 'exclusive') {
        return "- if $x $op $value";
    } elsif ($class eq 'inclusive') {
        return "+ if $x $op $value";
    } elsif ($class eq 'multiplicative') {
        return "* $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($x - $x_min)";
    }
}

sub name {
    my ($self, %args) = @_;

    my $class = $self->layer->rule_class->name;

    my $x = $self->r_layer ? 
        $self->r_layer->name : 
        ($self->r_dataset ? $self->r_dataset->name : 'undefined');
    
    my $op = $self->op->name;
    my $value = $args{no_value} ? '' : $self->value;
    my $x_min = $self->min_value;
    my $x_max = $self->max_value;
    my $y_min = $self->value_at_min;
    my $y_max = $self->value_at_max;
    my $w = $self->weight;
    
    if ($class eq 'additive') {
        return "+ $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($x - $x_min)";
    } elsif ($class eq 'exclusive') {
        return "- if $x $op $value";
    } elsif ($class eq 'inclusive') {
        return "+ if $x $op $value";
    } elsif ($class eq 'multiplicative') {
        return "* $y_min - $w * ($y_max-$y_min)/($x_max-$x_min) * ($x - $x_min)";
    }
}

sub as_hashref_for_json {
    my ($self) = @_;
    my $desc = $self->r_dataset ? $self->r_dataset->descr : '';
    return {
        name => $self->name(no_value => 1),
        id => $self->id, 
        active => JSON::true,
        value => $self->value,
        min => $self->min_value() // 0,
        max => $self->max_value() // 10,
        type => $self->value_type() // 'int',
        description => $desc,
    };
}

# this is needed by modify request
sub values {
    my ($self) = @_;
    my %values;
    for my $key (keys %attributes) {
        if ($attributes{$key}{input} eq 'lookup') {
            my $foreign = $self->$key;
            $values{$key} = $self->$key->id if $foreign;
        } else {
            $values{$key} = $self->$key;
        }
    }
    return \%values;
}

sub apply {
    my ($self, $method, $y, $rules, $debug) = @_;

    # the operand (x)
    my $x = $self->operand($rules);
    
    if ($debug) {
        if ($debug > 1) {
            print STDERR $x;
        } else {
            my @stats = stats($x); # 3 and 4 are min and max
            say STDERR "  operand min=$stats[3], max=$stats[4]";
        }
    }

    if ($method =~ /^incl/) {

        # the default is to compare the spatial operand to 1
        my $op = $self->op ? $self->op->name : '==';
        my $value = $self->value // 1;

        if (defined $x) {
            if ($op eq '<=')    { $y->where($x <= $value) .= 1; } 
            elsif ($op eq '<')  { $y->where($x <  $value) .= 1; }
            elsif ($op eq '>=') { $y->where($x >= $value) .= 1; }
            elsif ($op eq '>')  { $y->where($x >  $value) .= 1; }
            elsif ($op eq '==') { $y->where($x == $value) .= 1; }
            else                { say STDERR "rule is a no-op: ",$self->name; }
        }   
        else                    { $y .= 1; }

    } elsif ($method =~ /^excl/) {
        
        # the default is to compare the spatial operand to 1
        my $op = $self->op ? $self->op->name : '==';
        my $value = $self->value // 1;
        
        if (defined $x) {
            if ($op eq '<=')    { $y->where($x <= $value) .= 0; } 
            elsif ($op eq '<')  { $y->where($x <  $value) .= 0; }
            elsif ($op eq '>=') { $y->where($x >= $value) .= 0; }
            elsif ($op eq '>')  { $y->where($x >  $value) .= 0; }
            elsif ($op eq '==') { $y->where($x == $value) .= 0; }
            else                { say STDERR "rule is a no-op: ",$self->name; }
        }   
        else                    { $y .= 0; }

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
    if ($self->r_layer) {
        # we need the rules associated with the 2nd plan.use.layer
        my $plan = $self->r_plan ? $self->r_plan : $self->plan;
        my $use = $self->r_use ? $self->r_use : $self->use;
            
        # TODO: how to avoid circular references?

        my $rules = SmartSea::Layer->new($rules->{schema}, $plan, $use, $self->r_layer);

        say STDERR 
            $plan->name,".",$use->name,".",$self->r_layer->name,
            " did not return any rules" unless $rules->rules;
        
        if ($self->r_layer->name eq 'Allocation') {
            return $rules->compute_allocation($rules);
        } else {
            return $rules->compute_value($rules);
        }
    } elsif ($self->r_dataset) {
        return $self->r_dataset->Piddle($rules);
    }
    return undef;
}

1;
