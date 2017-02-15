package SmartSea::Rules;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use PDL;

use SmartSea::Core qw(:all);

# an ordered set of rules to create a layer for a use in a plan
# the default order of rules is defined in the rules table using "my_index"
# layer name is a sequence of integers separated with non-numbers (a trail)
# trail = plan use layer [rule*]

sub new {
    my ($class, $self) = @_; # must give schema, cookie, and trail
    my $trail = $self->{trail};
    my $schema = $self->{schema};
    my $id;
    ($trail, $id) = parse_integer($trail);
    if ($id eq '') {
        return bless $self, $class;
    }
    
    my $plan = $schema->resultset('Plan')->single({ id => $id });
    ($trail, $id) = parse_integer($trail);
    
    if ($id == 0) {
        ($trail, $id) = parse_integer($trail);
        $self->{dataset} = $schema->resultset('Dataset')->single({ id => $id });
        return bless $self, $class;
    }
    
    my $use = $schema->resultset('Use')->single({ id => $id });
    ($trail, $id) = parse_integer($trail);
    my $layer = $schema->resultset('Layer')->single({ id => $id });

    my $plan2use = $schema->resultset('Plan2Use')->single({plan => $plan->id, use => $use->id});
    my $pul = $schema->resultset('Plan2Use2Layer')->single({plan2use => $plan2use->id, layer => $layer->id});
    $self->{pul} = $pul;
    $self->{class} = $pul->rule_class;
    $self->{max} = $pul->additive_max;

    my @rules;
    # rule list is optional
    if ($trail) {
        # rule order is defined by the client in this case
        while ($trail) {            
            ($trail, $id) = parse_integer($trail);
            # there may be default rule and a modified rule denoted with a cookie
            # prefer the one with our cookie
            my $rule;
            for my $r ($schema->resultset('Rule')->search({ id => $id })) {
                if ($r->cookie eq $self->{cookie}) {
                    $rule = $r;
                    last;
                }
                $rule = $r if $r->cookie eq DEFAULT;
            }
            # maybe we should test $rule->plan and $rule->use?
            # and that the $rule->layer->id is the same?
            push @rules, $rule;
        }
    } elsif ($self->{pul}) {
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
            push @rules, $rules{$i};
        }
    }
    
    $self->{plan} = $plan;
    $self->{use} = $use;
    $self->{layer} = $layer;
    $self->{rules} = \@rules;
    
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

sub compute {
    my ($self, $debug) = @_;

    my $result = zeroes($self->{tile}->tile);

    my $method = $self->{class}->name;

    if ($method =~ /^seq/ || $method =~ /^mult/) {
        $result += 1; # 
    }

    for my $rule ($self->rules) {
        if ($debug) {
            my @stats = stats($result); # 3 and 4 are min and max
            say STDERR "result now min=$stats[3], max=$stats[4]";
            my $val = $rule->value // 1;
            say STDERR $rule->as_text," ",$val;
        }
        $rule->apply($method, $result, $self, $debug);
    }

    if ($method =~ /^add/) {
        $result /= $self->max;
        $result->where($result > 1) .= 1;
    }

    return $result;
}

1;
