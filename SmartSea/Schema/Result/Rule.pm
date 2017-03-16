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
    reduce => {
        i => 4,
        input => 'checkbox',
        cue => 'Rule removes allocation/value',
    },
    r_plan => {
        i => 5,
        input => 'lookup',
        class => 'Plan',
        allow_null => 1
    },
    r_use => {
        i => 6,
        input => 'lookup',
        class => 'Use',
        allow_null => 1
    },
    r_layer => {
        i => 7,
        input => 'lookup',
        class => 'Layer',
        allow_null => 1
    },
    r_dataset => {
        i => 8,
        input => 'lookup',
        class => 'Dataset',
        objs => {path => {'!=',undef}},
        allow_null => 1
    },
    op => {
        i => 9,
        input => 'lookup',
        class => 'Op',
        allow_null => 1
    },
    value => {
        i => 10,
        input => 'text',
        type => 'double'
    },
    min_value => {
        i => 11,
        input => 'text',
        type => 'double'
    },
    max_value => {
        i => 12,
        input => 'text',
        type => 'double'
    },
    my_index => {
        i => 13,
        input => 'spinner'
    },
    value_type => {
        i => 14,
        input => 'text',
    },
    value_at_min => {
        i => 15,
        input => 'text',
        type => 'double'
    },
    value_at_max => {
        i => 16,
        input => 'text',
        type => 'double'
    },
    weight => {
        i => 17,
        input => 'text',
        type => 'double'
    }
    );

# how to compute the weighted value for x:
# w_r = weight * (value_at_min + (x - min_value)*(value_at_max - value_at_min)/(max_value - min_value))
# value_at_min and value_at_max are between 0 and 1
# x, min_value and max_value are in data units
# 
# to combine multiple rules, multiply
# suitability = multiply_all(w_r_1 ... w_r_n)

__PACKAGE__->table('tool.rules');
__PACKAGE__->add_columns('id', 'cookie', 'made', 'plan2use2layer', keys %attributes);
__PACKAGE__->set_primary_key('id', 'cookie');

__PACKAGE__->belongs_to(plan2use2layer => 'SmartSea::Schema::Result::Plan2Use2Layer');

__PACKAGE__->belongs_to(r_plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(r_use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(r_layer => 'SmartSea::Schema::Result::Layer');

__PACKAGE__->belongs_to(r_dataset => 'SmartSea::Schema::Result::Dataset');

__PACKAGE__->belongs_to(op => 'SmartSea::Schema::Result::Op');

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    if (@{$args{oids}}) {
        say STDERR "Too long oid list: @{$args{oids}}";
        return undef;
    }
    my $obj;
    say STDERR "get rule $oid, $args{cookie}";
    eval {
        $obj = $args{schema}->resultset('Rule')->single({id => $oid, cookie => $args{cookie}});
    };
    say STDERR "Error: $@" if $@;
    return $obj;
}

sub create_col_data {
    my $class = shift;
    my %col_data;
    for my $parameters (@_) {
        for my $col (qw/plan2use2layer cookie my_index r_dataset/) { # or r_plan, r_use, r_layer (or is that r_pul?)
            $col_data{$col} //= $parameters->{$col};
            say STDERR "create rule: $col => $parameters->{$col}" if defined $parameters->{$col};
        }
    }
    return \%col_data;
}

sub update_col_data {
    my ($class, $parameters) = @_;
    my %col_data;
    for my $col (keys %attributes) {
        next unless defined $parameters->{$col};
        my $type = $attributes{$col}{type} // '';
        $parameters->{$col} = undef if $type eq 'double' && $parameters->{$col} eq '';
        $col_data{$col} = $parameters->{$col};
    }
    return \%col_data;
}

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

sub as_text {
    my ($self, %args) = @_;
    return $self->r_dataset ? $self->r_dataset->long_name : 'error' if $self->plan2use2layer->layer->id == 1;
    my $text;
    $text = $self->reduce ? "- If " : "+ If ";
    my $u = '';
    $u = $self->r_use->name if $self->r_use && $self->r_use->name ne $self->use->name;
    if (!$self->r_layer) {
    } elsif ($self->r_layer->name eq 'Value') {
        $u = "for ".$u if $u;
        $text .= $self->r_layer->name.$u;
    } elsif ($self->r_layer->name eq 'Allocation') {
        $u = "of ".$u if $u;
        $text .= $self->r_layer->name.$u;
        $text .= $self->r_plan ? " in plan".$self->r_plan->name : " of this plan";
    } # else?
    if ($self->r_dataset) {
        #$text .= $self->r_dataset->long_name;
        $text .= $self->r_dataset->name;
    }
    return $text." (true)" unless $self->op;
    $text .= " ".$self->op->name;
    $text .= " ".$self->value if $args{include_value};
    return $text;
}

sub as_hashref_for_json {
    my ($self) = @_;
    my $desc = $self->r_dataset ? $self->r_dataset->descr : '';
    return {
        name => $self->as_text(include_value => 0), 
        id => $self->id, 
        active => JSON::true, 
        index => $self->my_index,
        value => $self->value,
        min => $self->min_value() // 0,
        max => $self->max_value() // 10,
        type => $self->value_type() // 'int',
        description => $desc,
    };
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    my $sequential = $self->plan2use2layer->rule_class->name =~ /^sequential/;
    my @cols;
    if ($sequential) {
        @cols = (qw/r_plan r_use r_layer r_dataset reduce op value min_value max_value my_index/);
    } else {
        @cols = (qw/r_plan r_use r_layer r_dataset min_value max_value value_at_min value_at_max weight/);
    }
    push @l, ([li => [b => 'Rule']]) unless $args{plan};
    #for my $a ('id', sort {$attributes{$a}{i} <=> $attributes{$b}{i}} keys %attributes) {
    for my $a ('id', @cols) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/name id data/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    #push @l, [li => a(url => "$args{uri}?edit", link => 'edit')] if $args{edit};
    return [ li => [0 => 'Rule:'], [ul => \@l] ] if $args{named_item};
    return [ div => $attributes, [ul => \@l] ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;
    # todo: args.fixed to render some attributes to unchangeable (mainly plan, use, layer
    my $pul = $self->plan2use2layer;
    my $plan = $pul->plan2use->plan;
    my $use = $pul->plan2use->use;
    my $layer = $pul->layer;
    
    my @form;
    
    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Rule')) {
        for my $key (keys %attributes) {
            next unless defined $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }
    push @form, [input => {type => 'hidden', name => 'cookie', value => 'default'}];
    
    my $widgets = widgets(\%attributes, $values, $args{schema});

    push (@form,
          [ p => $plan->name.'.'.$use->name.'.'.$layer->name],
          [ p => 'Spatial dataset for this Rule:' ],
          [ p => [[1 => 'plan: '],$widgets->{r_plan}] ],
          [ p => [[1 => 'use: '],$widgets->{r_use}] ],
          [ p => [[1 => 'layer: '],$widgets->{r_layer}] ],
          [ p => 'or' ],
          [ p => [[1 => 'dataset: '],$widgets->{r_dataset}] ],
          [ p => [[1 => 'Range of data values: '],$widgets->{min_value},[1 => '...'],$widgets->{max_value}] ],
          ['hr']);
    if ($pul->rule_class eq 'sequentially') {
        push (@form,
              [ p => $widgets->{reduce} ],
              [ p => [[1 => 'Operator and threshold value: '],$widgets->{op},$widgets->{value}] ],
              [ p => [[1 => 'Index in sequence: '],$widgets->{my_index}] ],
              [ p => [[1 => 'Type of value: '],$widgets->{value_type}] ]);
    } else {
        push (@form,
              [ p => [[1 => 'Range of values: '],$widgets->{value_at_min},
                      [1 => '...'],$widgets->{value_at_max}] ],
              [ p => [[1 => 'Weigth: '],$widgets->{weight}] ]);
    }
    push (@form,
          ['hr'],
          button(value => "Store"),
          [1 => ' '],
          button(value => "Cancel")
        );
    return [form => $attributes, @form];
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %data;
    my %plans;
    my %uses;
    my %layers;
    my $sequential = $args{rule_class} eq 'sequentially';
    for my $rule (sort {$a->my_index <=> $b->my_index} @$objs) {
        my $li;
        if ($sequential) {
            $li = item($rule->as_text(include_value => 1)." (".$rule->my_index.")", $rule->id, %args, ref => 'this rule');
        } else {
            $li = item($rule->r_dataset->name, $rule->id, %args, ref => 'this rule');
        }
        my $plan2use2layer = $rule->plan2use2layer;
        my $plan2use = $plan2use2layer->plan2use;
        my $plan = $plan2use->plan;
        my $use = $plan2use->use;
        my $layer = $plan2use2layer->layer;
        $plans{$plan->name} = 1;
        $uses{$use->name} = 1;
        $layers{$layer->name} = 1;
        push @{$data{$plan->name}{$use->name}{$layer->name}}, [li => $li];
    }
    my @li;
    if (keys %plans == 1 && keys %uses == 1 && keys %layers == 1) {
        my $plan = (keys %plans)[0];
        my $use = (keys %uses)[0];
        my $layer = (keys %layers)[0];
        push @li, @{$data{$plan}{$use}{$layer}};
    } else {
        for my $plan (sort keys %data) {
            my @l;
            for my $use (sort keys %{$data{$plan}}) {
                my @l2;
                for my $layer (sort keys %{$data{$plan}{$use}}) {
                    push @l2, [li => [[b => $layer], [ol => \@{$data{$plan}{$use}{$layer}}]]];
                }
                push @l, [li => [[b => $use], [ul => \@l2]]];
            }
            push @li, [li => [[b => $plan], [ul => \@l]]];
        }
    }

    if ($args{edit}) {
        my @objs = $args{schema}->resultset('Dataset')->search({path => { '!=', undef }});
        my $drop_down = drop_down(name => 'r_dataset', objs => \@objs);
        push @li, [li => [$drop_down, [0 => ' '],
                          button(value => 'Add', name => 'rule')]];
    }
    
    my $ret = [ul => \@li];
    $ret = [ol => \@li] if $args{rule_class} =~ /^seq/;
    return [ li => [0 => 'Rules:'], $ret ] if $args{named_list};
    return $ret;
}

sub apply {
    my ($self, $method, $y, $rules, $debug) = @_;

    # the operand (x)
    my $x = $self->operand($rules);
    my $x_min = $self->min_value;
    my $x_max = $self->max_value;

    if ($debug) {
        my @stats = stats($x); # 3 and 4 are min and max
        say STDERR "  operand min=$stats[3], max=$stats[4]";
    }

    my $w = $self->weight;

    # output is y
    my $y_min = $self->value_at_min // 0;
    my $y_max = $self->value_at_max // 1;

    if ($method =~ /^mult/) {

        $y *= $w * ($y_min + ($x-$x_min)*($y_max-$y_min)/($x_max-$x_min));

    } elsif ($method =~ /^add/) {

        $y += $w * ($y_min + ($x-$x_min)*($y_max-$y_min)/($x_max-$x_min));

    } elsif ($method =~ /^seq/) {
        
        # if $rule->reduce then deallocate where the rule is true
        my $val = $self->reduce ? 0 : 1;

        # the default is to compare the spatial operand to 1
        my $op = $self->op ? $self->op->name : '==';
        my $value = $self->value // 1;
        
        if (defined $x) {
            if ($op eq '<=')    { $y->where($x <= $value) .= $val; } 
            elsif ($op eq '<')  { $y->where($x <  $value) .= $val; }
            elsif ($op eq '>=') { $y->where($x >= $value) .= $val; }
            elsif ($op eq '>')  { $y->where($x >  $value) .= $val; }
            elsif ($op eq '==') { $y->where($x == $value) .= $val; }
            else                { say STDERR "rule is a no-op: ",
                                  $self->as_text(include_value => 1); }
        }   
        else                    { $y .= $val; }

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
