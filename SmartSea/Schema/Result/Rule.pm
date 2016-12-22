package SmartSea::Schema::Result::Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use PDL;

use SmartSea::Core;
use SmartSea::HTML qw(:all);
use SmartSea::Rules;

my %attributes = (
    plan => {
        i => 1,
        type => 'lookup',
        class => 'Plan',
        allow_null => 1
    },
    use => {
        i => 2,
        type => 'lookup',
        class => 'Use'
    },
    layer => {
        i => 3,
        type => 'lookup',
        class => 'Layer'
    },
    reduce => {
        i => 4,
        type => 'checkbox',
        cue => 'Rule removes allocation/value',
    },
    r_plan => {
        i => 5,
        type => 'lookup',
        class => 'Plan',
        allow_null => 1
    },
    r_use => {
        i => 6,
        type => 'lookup',
        class => 'Use',
        allow_null => 1
    },
    r_layer => {
        i => 7,
        type => 'lookup',
        class => 'Layer',
        allow_null => 1
    },
    r_dataset => {
        i => 8,
        type => 'lookup',
        class => 'Dataset',
        objs => {path => {'!=',undef}},
        allow_null => 1
    },
    op => {
        i => 9,
        type => 'lookup',
        class => 'Op',
        allow_null => 1
    },
    value => {
        i => 10,
        type => 'text'
    },
    min_value => {
        i => 11,
        type => 'text'
    },
    max_value => {
        i => 12,
        type => 'text'
    },
    my_index => {
        i => 13,
        type => 'spinner'
    },
    value_type => {
        i => 14,
        type => 'text'
    }
    );

__PACKAGE__->table('tool.rules');
__PACKAGE__->add_columns('id', keys %attributes);
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
    my ($self, %arg) = @_;
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
        #$text .= $self->r_dataset->long_name;
        $text .= $self->r_dataset->name;
    }
    return $text." (true)" unless $self->op;
    $text .= " ".$self->op->op;
    $text .= " ".$self->value if $arg{include_value};
    return $text;
}

sub as_hashref_for_json {
    my ($self) = @_;
    my $desc = $self->r_dataset ? $self->r_dataset->descr : '';
    return {
        title => $self->as_text(include_value => 0), 
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

sub HTML_text {
    my ($self) = @_;
    my @l = ([li => 'Rule']);
    for my $a ('id', sort {$attributes{$a}{i} <=> $attributes{$b}{i}} keys %attributes) {
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

sub HTML_form {
    my ($self, $config, $values) = @_;

    my @ret;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Rule')) {
        for my $key (keys %attributes) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @ret, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }
    
    my $widgets = widgets(\%attributes, $values, $config->{schema});

    push @ret, (
        [ p => [[1 => 'Plan: '],$widgets->{plan}] ],
        [ p => [[1 => 'Use: '],$widgets->{use}] ],
        [ p => [[1 => 'Layer: '],$widgets->{layer}] ],
        [ p => $widgets->{reduce} ],
        [ p => 'Layer in the rule:' ],
        [ p => [[1 => 'plan: '],$widgets->{r_plan}] ],
        [ p => [[1 => 'use: '],$widgets->{r_use}] ],
        [ p => [[1 => 'layer: '],$widgets->{r_layer}] ],
        [ p => 'or' ],
        [ p => [[1 => 'dataset: '],$widgets->{r_dataset}] ],
        [ p => [[1 => 'Operator and value: '],$widgets->{op},$widgets->{value}] ],
        [ p => [[1 => 'Range of value: '],$widgets->{min_value},[1 => '...'],$widgets->{max_value}] ],
        [ p => [[1 => 'Index in this plan.use.layer: '],$widgets->{my_index}] ],
        [ p => [[1 => 'Type of value: '],$widgets->{value_type}] ],
        button(value => "Store"),
        [1 => ' '],
        button(value => "Cancel")
    );
    return \@ret;
}

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    for my $rule (sort {$a->my_index <=> $b->my_index} @$objs) {
        my $li = item($rule->as_text(include_value => 1)." (".$rule->my_index.")", $rule->id, $uri, $edit, 'this rule');
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
                push @l2, [li => [[b => $layer], [ol => \@{$data{$plan}{$use}{$layer}}]]];
            }
            push @l, [li => [[b => $use], [ul => \@l2]]];
        }
        push @body, [b => $plan], [ul => \@l];
    }
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, a(link => 'add', url => $uri.'/new');
    }
    return \@body;
}

sub operand {
    my ($self, $config, $use, $tile) = @_;
    if ($self->r_layer) {
        # we need the rules associated with the 2nd plan.use.layer
        my $plan = $self->r_plan ? $self->r_plan : $self->plan;
        my $use = $self->r_use ? $self->r_use : $self->use;
            
        # TODO: how to avoid circular references?

        my $rules = SmartSea::Rules->new($config->{schema}, $plan, $use, $self->r_layer);

        say STDERR $plan->title,".",$use->title,".",$self->r_layer->title," did not return any rules" unless $rules->rules;
        
        if ($self->r_layer->title eq 'Allocation') {
            return $rules->compute_allocation($config, $tile);
        } else {
            return $rules->compute_value($config, $tile);
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
        my $b;
        eval {
            $b = Geo::GDAL::Open("$config->{data_path}/$path")
                ->Translate( "/vsimem/tmp.tiff", 
                             ['-of' => 'GTiff', '-r' => 'nearest' , 
                              '-outsize' , $tile->tile,
                              '-projwin', $tile->projwin] )
                ->Band(1);
        };
        my $pdl;
        if ($@) {
            $pdl = zeroes($tile->tile);
            $pdl = $pdl->setbadif($pdl == 0);
        } else {
            $pdl = $b->Piddle;
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
        }

        return $pdl;
    }
}

1;
