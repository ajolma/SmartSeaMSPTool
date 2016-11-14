package SmartSea::Schema::Result::Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core;
use SmartSea::HTML;
use PDL;

__PACKAGE__->table('tool.rules');
__PACKAGE__->add_columns(qw/ id plan use layer reduce r_plan r_use r_layer r_dataset op value min_value max_value /);
__PACKAGE__->set_primary_key('id');

# determines whether an area is allocated to a use in a plan
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(layer => 'SmartSea::Schema::Result::Layer');

# by default the area is allocated to the use
# if reduce is true, the rule disallocates
# rule consists of an use, layer type, plan (optional, default is this plan)
# operator (optional), value (optional)

__PACKAGE__->belongs_to(r_plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(r_use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(r_layer => 'SmartSea::Schema::Result::Layer');

__PACKAGE__->belongs_to(r_dataset => 'SmartSea::Schema::Result::Dataset');

__PACKAGE__->belongs_to(op => 'SmartSea::Schema::Result::Op');


sub as_text {
    my ($self) = @_;
    return $self->r_dataset ? $self->r_dataset->long_name : 'error' if $self->layer->id == 1;
    my $text;
    $text = $self->reduce ? "- If " : "+ If ";
    my $u = '';
    $u = $self->r_use->title if $self->r_use && $self->r_use->title ne $self->use->title;
    if (!$self->r_layer) {
    } elsif ($self->r_layer->title eq 'Value') {
        $u = "for ".$u if $u;
        $text .= $self->r_layer->title.$u;
    } elsif ($self->r_layer->title eq 'Allocation') {
        $u = "of ".$u if $u;
        $text .= $self->r_layer->title.$u;
        $text .= $self->r_plan ? " in plan".$self->r_plan->title : " of this plan";
    } # else?
    if ($self->r_dataset) {
        $text .= $self->r_dataset->long_name." ";
    }
    return $text."(true)" unless $self->op;
    return $text." is ".$self->op->op." ".$self->value;
}

sub HTML_text {
    my ($self) = @_;
    my @l;
    for my $a (qw/id plan use layer reduce r_plan r_use r_layer r_dataset op value min_value max_value/) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/title name data op id/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    return [ul => \@l];
}

sub drop_down {
    my ($col, $rs, $values, $allow_null) = @_;
    my %objs;
    my %visuals;
    %visuals = ('NULL' => '') if $allow_null;
    for my $obj ($rs->all) {
        $objs{$obj->id} = $obj->title;
        $visuals{$obj->id} = $obj->title;
    }
    my @values = sort {$objs{$a} cmp $objs{$b}} keys %objs;
    unshift @values, 'NULL' if $allow_null;
    return SmartSea::HTML->select(
        name => $col,
        values => [@values],
        visuals => \%visuals,
        selected => $values->{$col} // ($allow_null ? 'NULL' : '')
    );
}

sub HTML_form {
    my ($self, $config, $values) = @_;

    my @ret;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Rule')) {
        for my $key (qw/plan use reduce r_plan r_use r_layer r_dataset op value min_value max_value/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @ret, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $plan = drop_down('plan', $config->{schema}->resultset('Plan'), $values, 1);
    my $use = drop_down('use', $config->{schema}->resultset('Use'), $values);
    my $layer = drop_down('layer', $config->{schema}->resultset('Layer'), $values);

    my $reduce = SmartSea::HTML->checkbox(
        name => 'reduce',
        visual => 'Rule removes allocation/value',
        checked => $values->{reduce}
    );

    my $r_plan = drop_down('r_plan', $config->{schema}->resultset('Plan'), $values, 1);
    my $r_use = drop_down('r_use', $config->{schema}->resultset('Use'), $values, 1);
    my $r_layer = drop_down('r_layer', $config->{schema}->resultset('Layer'), $values, 1);

    my %r_datasets;
    my %visuals = ('NULL' => '');
    for my $r_dataset ($config->{schema}->resultset('Dataset')->all) {
        next unless $r_dataset->path;
        $r_datasets{$r_dataset->id} = $r_dataset->long_name;
        $visuals{$r_dataset->id} = $r_dataset->long_name;
    }
    my $r_dataset = SmartSea::HTML->select(
        name => 'r_dataset',
        values => ['NULL', sort {$r_datasets{$a} cmp $r_datasets{$b}} keys %r_datasets], 
        visuals => \%visuals,
        selected => $values->{r_dataset} // 'NULL'
    );

    my $op = drop_down('op', $config->{schema}->resultset('Op'), $values, 1);

    my $value = SmartSea::HTML->text(
        name => 'value',
        size => 10,
        visual => $values->{value} // ''
    );

    my $min_value = SmartSea::HTML->text(
        name => 'min_value',
        size => 10,
        visual => $values->{min_value} // ''
    );
    my $max_value = SmartSea::HTML->text(
        name => 'max_value',
        size => 10,
        visual => $values->{max_value} // ''
    );

    push @ret, (
        [ p => [[1 => 'plan: '],$plan] ],
        [ p => [[1 => 'use: '],$use] ],
        [ p => [[1 => 'layer: '],$layer] ],
        [ p => $reduce ],
        [ p => 'Layer in the rule:' ],
        [ p => [[1 => 'plan: '],$r_plan] ],
        [ p => [[1 => 'use: '],$r_use] ],
        [ p => [[1 => 'layer: '],$r_layer] ],
        [ p => 'or' ],
        [ p => [[1 => 'dataset: '],$r_dataset] ],
        [ p => [[1 => 'Operator and value: '],$op,$value] ],
        [ p => [[1 => 'Range of value: '],$min_value,[1=>'...'],$max_value] ],
        [input => {type=>"submit", name=>'submit', value=>"Store"}]
    );
    return \@ret;
}

sub HTML_list {
    my (undef, $rs, $uri, $allow_edit) = @_;
    my %data;
    my $html = SmartSea::HTML->new;
    for my $rule ($rs->search(undef, {order_by => [qw/me.id/]})) {
        my $li = [ $html->a(link => $rule->as_text, url => $uri.'/'.$rule->id) ];
        if ($allow_edit) {
            push @$li, (
                [1 => '  '],
                $html->a(link => "edit", url => $uri.'/'.$rule->id.'?edit'),
                [1 => '  '],
                [input => {type=>"submit", 
                           name=>$rule->id, 
                           value=>"Delete",
                           onclick => "return confirm('Are you sure you want to delete this rule?')" 
                 }
                ]
            )
        }
        if ($rule->plan) {
            push @{$data{$rule->plan->title}{$rule->use->title}{$rule->layer->title}}, [li => $li];
        } else {
            push @{$data{'0 Default'}{$rule->use->title}{$rule->layer->title}}, [li => $li];
        }
    }
    my @body;
    for my $plan (sort keys %data) {
        my @l;
        for my $use (sort keys %{$data{$plan}}) {
            my @l2;
            for my $layer (sort keys %{$data{$plan}{$use}}) {
                push @l2, [li => [[b => $layer], [ul => \@{$data{$plan}{$use}{$layer}}]]];
            }
            push @l, [li => [[b => $use], [ul => \@l2]]];
        }
        push @body, [b => $plan], [ul => \@l];
    }
    if ($allow_edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, $html->a(link => 'add', url => $uri.'/new');
    }
    return \@body;
}

# return rules for plan.use.layer
sub rules {
    my ($rs, $plan, $use, $layer) = @_;
    my @rules;
    my $remove_default;
    for my $rule ($rs->search({ -or => [ plan => $plan->id,
                                         plan => undef ],
                                use => $use->id,
                                layer => $layer->id
                              },
                              { order_by => ['me.id'] })) {
                
        # if there are rules for this plan, remove default rules
        $remove_default = 1 if $rule->plan;
        push @rules, $rule;
    }
    my @final;
    for my $rule (@rules) {
        next if $remove_default && !$rule->plan;
        push @final, $rule;
    }
    return @final;
}

sub compute_allocation {
    my ($config, $use, $tile, $rules) = @_;

    # default is to allocate all
    my $result = zeroes($tile->tile) + 2;

    for my $rule (@$rules) {

        # a rule is a spatial rule to allocate or deallocate

        # if $rule->reduce then deallocate where the rule is true
        my $val = $rule->reduce ? 0 : 2;

        # the default is to compare the spatial operand to 1
        my $op = $rule->op ? $rule->op->op : '==';
        my $value = $rule->value // 1;

        # the operand
        my $tmp = $rule->operand($config, $use, $tile);

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
    my $current = $use->current_allocation;
    $current = $current->path if $current;
    $result->where(dataset($config, $tile, $current) > 0) .= 1 if $current;

    return $result;
}

sub compute_value {
    my ($config, $use, $tile, $rules) = @_;

    # default is no value
    my $result = zeroes($tile->tile);
    return $result unless @$rules;

    # apply rules
    for my $rule (@$rules) {

        # a rule is a spatial rule to add value or reduce value
        my $sign = $rule->reduce ? -1 : 1;

        # the default is to use the value as a weight
        my $value = $rule->value // 1;
        $value *= $sign;

        # operator is not used?
        #my $op = $rule->op ? $rule->op->op : '==';

        # the operand
        my $tmp = double($rule->operand($config, $use, $tile));

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
    $result = short($result/@$rules + 0.5);

    return $result;
}

sub operand {
    my ($self, $config, $use, $tile) = @_;
    if ($self->r_layer) {
        # we need the rules associated with the 2nd plan.use.layer
        my $plan = $self->r_plan ? $self->r_plan : $self->plan;
        my $use = $self->r_use ? $self->r_use : $self->use;
            
        # TODO: how to avoid circular references?
                
        my @rules = rules($config->{schema}->resultset('Rule'), $plan, $use, $self->r_layer);

        say STDERR $plan->title,".",$use->title,".",$self->r_layer->title," did not return any rules" unless @rules;
        
        if ($self->r_layer->title eq 'Allocation') {
            return compute_allocation($config, $use, $tile, \@rules);
        } else {
            return compute_value($config, $use, $tile, \@rules);
        }
    } elsif ($self->r_dataset) {
        return dataset($config, $tile, $self->r_dataset->path);
    }
    return undef;
}

sub dataset {
    my ($config, $tile, $path) = @_;

    if ($path =~ /^PG:/) {
        $path =~ s/^PG://;

        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->Create(Name => "/vsimem/r.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>3067));
        $config->{GDALVectorDataset}->Rasterize($ds, [-burn => 1, -l => $path]);
        return $ds->Band(1)->Piddle;
        
    } else {
        my $b = Geo::GDAL::Open("$config->{data_path}/$path")
            ->Translate( "/vsimem/tmp.tiff", 
                         ['-of' => 'GTiff', '-r' => 'nearest' , 
                          '-outsize' , $tile->tile,
                          '-projwin', $tile->projwin] )
            ->Band(1);
        my $pdl = $b->Piddle;
        my $bad = $b->NoDataValue();
        
        # this is a hack
        if (defined $bad) {
            if ($bad < -1000) {
                $pdl = $pdl->setbadif($pdl < -1000);
            } elsif ($bad > 1000) {
                $pdl = $pdl->setbadif($pdl > 1000);
            } else {
                $pdl = $pdl->setbadif($pdl == $bad);
            }
        }

        return $pdl;
    }
}

1;
