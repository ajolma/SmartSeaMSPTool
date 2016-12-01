package SmartSea::Rules;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use PDL;

use SmartSea::Core qw(:all);

# a set of rules for plan.use.layer

sub new {
    my ($class, $schema, $plan, $use, $layer, @rules);
    if (@_ == 3) {
        my $trail;
        ($class, $schema, $trail) = @_;
        my $id;
        ($trail, $id) = parse_integer($trail);
        $plan = $schema->resultset('Plan')->single({ id => $id });
        ($trail, $id) = parse_integer($trail);
        $use = $schema->resultset('Use')->single({ id => $id });
        ($trail, $id) = parse_integer($trail);
        $layer = $schema->resultset('Layer')->single({ id => $id });
        if ($trail) {
            while ($trail) {
                # rule application order is defined by the client
                ($trail, $id) = parse_integer($trail);
                my $rule = $schema->resultset('Rule')->single({ id => $id });
                # maybe we should test $rule->plan and $rule->use?
                # and that the $rule->layer->id is the same?
                push @rules, $rule;
            }
        }
    } else {
        ($class, $schema, $plan, $use, $layer) = @_;
    }
    unless (@rules) {
        my $remove_default;
        my @tmp;
        for my $rule ($schema->resultset('Rule')->search(
                          { -or => [ plan => $plan->id,
                                     plan => undef ],
                            use => $use->id,
                            layer => $layer->id
                          },
                          { order_by => ['me.id'] })) {
            
            # if there are rules for this plan, remove default rules
            $remove_default = 1 if $rule->plan;
            push @rules, $rule;
        }
        for my $rule (@tmp) {
            next if $remove_default && !$rule->plan;
            push @rules, $rule;
        }
    }
    my $self = {rules => \@rules, plan => $plan, use => $use, layer => $layer};
    return bless $self, $class;
}

sub plan {
    my ($self) = @_;
    return $self->{plan};
}

sub use {
    my ($self) = @_;
    return $self->{use};
}

sub layer {
    my ($self) = @_;
    return $self->{layer};
}

sub rules {
    my ($self) = @_;
    return @{$self->{rules}};
}

sub has_rules {
    my ($self) = @_;
    return @{$self->{rules}} > 0;
}

sub compute_allocation {
    my ($self, $config, $tile) = @_;

    # default is to allocate all
    my $result = zeroes($tile->tile) + 2;

    for my $rule ($self->rules) {

        # a rule is a spatial rule to allocate or deallocate

        # if $rule->reduce then deallocate where the rule is true
        my $val = $rule->reduce ? 0 : 2;

        # the default is to compare the spatial operand to 1
        my $op = $rule->op ? $rule->op->op : '==';
        my $value = $rule->value // 1;

        # the operand
        my $tmp = $rule->operand($config, $self->{use}, $tile);

        if (defined $tmp) {
            if ($op eq '<=')    { $result->where($tmp <= $value) .= $val; } 
            elsif ($op eq '<')  { $result->where($tmp <  $value) .= $val; }
            elsif ($op eq '>=') { $result->where($tmp >= $value) .= $val; }
            elsif ($op eq '>')  { $result->where($tmp >  $value) .= $val; }
            elsif ($op eq '==') { $result->where($tmp == $value) .= $val; }
            else                { say STDERR "rule is a no-op: ",$rule->as_text; }
        }   
        else                    { $result .= $val; }
        
    }

    # set current allocation if there is one
    # TODO: how to deal with deallocations?
    my $current = $self->use->current_allocation;
    $current = $current->path if $current;
    $result->where(dataset($config, $tile, $current) > 0) .= 1 if $current;

    return $result;
}

sub compute_value {
    my ($self, $config, $tile) = @_;

    # default is no value
    my $result = zeroes($tile->tile);
    return $result unless @{$self->{rules}};

    # apply rules
    for my $rule (@{$self->{rules}}) {

        # a rule is a spatial rule to add value or reduce value
        my $sign = $rule->reduce ? -1 : 1;

        # the default is to use the value as a weight
        my $value = $rule->value // 1;
        $value *= $sign;

        # operator is not used?
        #my $op = $rule->op ? $rule->op->op : '==';

        # the operand
        my $tmp = double($rule->operand($config, $self->{use}, $tile));

        # scale values from 0 to 100
        my $min = $rule->min_value;
        my $max = $rule->max_value;
        $tmp = 100*($tmp-$min)/($max - $min) if $max - $min > 0;
        $tmp->where($tmp < 0) .= 0;
        $tmp->where($tmp > 100) .= 100;

        $result += $tmp;
    }

    # no negative values
    # how to deal with losses?
    $result->where($result < 0) .= 0;

    # scale values from 0 to 100 and round to integer values
    $result = short($result/@{$self->{rules}} + 0.5);

    return $result;
}

1;
