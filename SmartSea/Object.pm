package SmartSea::Object;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;
use SmartSea::HTML qw(:all);

our $debug = 2;

# in args give oid or lc_class, and possibly object or id
sub new {
    my ($class, $args, $args2) = @_;
    my $self = {};
    for my $key (qw/schema url edit dbname user pass data_dir/) {
        $self->{$key} = $args->{$key} // $args2->{$key};
    }
    my $oid = $args->{oid};
    my ($lc_class, $id);
    if ($oid) {
        ($lc_class, $id) = split /:/, $oid;
        say STDERR "split $oid => $lc_class,",(defined $id ? $id : 'undef') if $debug;
    }
    $lc_class //= $args->{lc_class};
    $lc_class = singular($lc_class);
    $self->{lc_class} = $lc_class;
    $lc_class =~ s/^(\w)/uc($1)/e;
    $lc_class =~ s/_(\w)/uc($1)/e;
    $lc_class =~ s/(\d\w)/uc($1)/e;
    $self->{source} = $lc_class;
    $self->{class} = 'SmartSea::Schema::Result::'.$lc_class;
    eval {
        $self->{rs} = $self->{schema}->resultset($self->{source});
        if ($args->{object}) {
            $self->{object} = $args->{object};
        } else {
            $id //= $args->{id};
            #say STDERR "source = $self->{source}, id = ",($id // 'undef') if $debug;
            $self->{object} = $self->{rs}->single({id => $id}) if $id;
        }
    };
    if ($@) {
        say STDERR "Error: $@" if $@;
        return undef;
    }
    bless $self, $class;
}

sub set_class_name {
    my ($self, $name) = @_;
    $self->{class_name} = $name;
}

sub class_name {
    my ($self, $parent, $purpose) = @_;
    return $self->{class_name} if $self->{class_name};
    return $self->{source} unless $self->{class}->can('class_name');
    return $self->{class}->class_name($parent->{object}, $purpose) unless $self->{object};
    return $self->{object}->class_name($parent->{object}, $purpose);
}

sub attributes {
    my ($self, $parent) = @_;
    return undef unless $self->{class}->can('attributes');
    return $self->{class}->attributes($parent->{object}) unless $self->{object};
    return $self->{object}->attributes($parent->{object});
}

sub create {
    my ($self, $oids, $parameters) = @_;
    my $parent = SmartSea::Object->new({oid => $oids->[$#$oids-1]}, $self);
    my $col_data = $self->{rs}->col_data_for_create($parent->{object}, $parameters);
    eval {
        $self->{rs}->create($col_data);
    };
    say STDERR "Error: $@" if $@;
    return "$@";
}

sub save {
    my ($self, $oids, $oids_index, $parameters) = @_;

    my $parent = $oids_index > 0 ? SmartSea::Object->new({oid => $oids->[$oids_index-1]}, $self) : undef;

    my $attributes = $self->attributes($parent);
    return "$self->{source} is non-editable" unless $attributes;
    my $col_data = {};

    unless ($self->{object}) {
        # create content objects, create this, and possibly link this into parents
        # content = the child does not exist on its own nor can be used by other objects (composition)
        # this can be an aggregate object but not a composed object
        
        if ($self->{rs}->can('col_data_for_create')) {
            say STDERR "parent oid = $oids->[$oids_index-1]" if $debug;
            my $parent = SmartSea::Object->new({oid => $oids->[$oids_index-1]}, $self);
            $col_data = $self->{rs}->col_data_for_create($parent->{object});
        }
        for my $class_of_child (keys %$attributes) {
            next unless $attributes->{$class_of_child}{input} eq 'object';
            unless ($parameters->{$class_of_child.'_is'}) {
                $col_data->{$class_of_child} = undef;
                next;
            }
            my $child = SmartSea::Object->new({lc_class => $class_of_child}, $self);
            # how to consume child parameters and possibly know them from our parameters?
            $child->save($oids, $oids_index, $parameters);
            $col_data->{$class_of_child} = $child->{object}->id;
        }
        for my $col (keys %$attributes) {
            next if $attributes->{$col}{input} eq 'object';
            next unless exists $parameters->{$col};
            next if $parameters->{$col} eq '' && $attributes->{$col}{empty_is_default};
            $col_data->{$col} = $parameters->{$col} if exists $parameters->{$col};
            $col_data->{$col} = undef if $attributes->{$col}{empty_is_null} && $col_data->{$col} eq '';
        }
        if ($self->{class}->can('is_ok')) {
            my $error = $self->{class}->is_ok($col_data);
            return $error if $error;
        }
        eval {
            say STDERR "create $self->{source}" if $debug;
            $self->{object} = $self->{rs}->create($col_data); # or add_to_x??
        };
        say STDERR "Error: $@" if $@;

        # add links to parents?

        return "$@";
        
    }

    my %delete;
    for my $class_of_child (keys %$attributes) {
        next unless $attributes->{$class_of_child}{input} eq 'object';
        if ($parameters->{$class_of_child.'_is'}) {
            unless (my $child = $self->{object}->$class_of_child) {
                $child = SmartSea::Object->new({lc_class => $class_of_child}, $self);
                # how to consume child parameters and possibly know them from our parameters?
                $child->save($oids, $oids_index, $parameters);
                $col_data->{$class_of_child} = $child->{object}->id;
            } else {
                $child = SmartSea::Object->new({lc_class => $class_of_child, object => $child}, $self);
                $child->save($oids, $oids_index, $parameters);
            }
        } else {
            $col_data->{$class_of_child} = undef;
            if (my $child = $self->{object}->$class_of_child) {
                $delete{$class_of_child} = $child; # todo: make child SmartSea::Object
            }
        }
    }

    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        next if $attributes->{$col}{input} eq 'ignore';
        next unless exists $parameters->{$col};
        next if $parameters->{$col} eq '' && $attributes->{$col}{empty_is_default};
        $col_data->{$col} = $parameters->{$col} if exists $parameters->{$col};
        $col_data->{$col} = undef if $attributes->{$col}{empty_is_null} && $col_data->{$col} eq '';
    }

    if ($self->{class}->can('is_ok')) {
        my $error = $self->{class}->is_ok($col_data);
        return $error if $error;
    }

    eval {
        say STDERR "update $self->{source} ",$self->{object}->id if $debug;
        for my $col (sort keys %$col_data) {
            say STDERR "  $col => ",(defined $col_data->{$col} ? $col_data->{$col} : 'undef') if $debug > 1;
        }
        $self->{object}->update($col_data);
    };
    say STDERR "Error: $@" if $@;

    # delete children:
    
    for my $class_of_child (keys %delete) {
        $delete{$class_of_child}->delete;
    }
    
    return "$@";
    
}

sub delete {
    my ($self) = @_;
    my $attributes = $self->attributes;
    unless ($self->{object}) {
        return "there is no $self->{source} object";
    }
    unless ($attributes) {
        return "$self->{source} is non-editable";
    }
    my %delete;
    for my $class_of_child (keys %$attributes) {
        if ($attributes->{$class_of_child}{input} eq 'object') {
            my $child = $self->{object}->$class_of_child;
            next unless $child;
            $delete{$class_of_child} = $child->id;
        }
    }
    eval {
        $self->{object}->delete;
    };
    say STDERR "Error: $@" if $@;
    for my $class_of_child (keys %delete) {
        my %args = (lc_class => $class_of_child, id => $delete{$class_of_child});
        my $child = SmartSea::Object->new(\%args, $self);
        $child->delete;
    }
    return "$@";
}

sub all {
    my ($self) = @_;
    return [$self->{rs}->list] if $self->{rs}->can('list');
    # todo: use self->rs and methods in it below
    my $order_by = $self->{class}->can('order_by') ? $self->{class}->order_by : {-asc => 'name'};
    return [$self->{rs}->search(undef, {order_by => $order_by})->all];
}

sub li {
    my ($self, $oids, $oids_index, $children, $opt) = @_;

    # todo: ecosystem component has an expected impact, which can be computed

    my $parent = $oids_index > 0 ? SmartSea::Object->new({oid => $oids->[$oids_index-1]}, $self) : undef;

    return $self->item_class($parent, $children, $opt) unless $self->{object};
    
    my $attributes = $self->attributes($parent);
    my $editable = $attributes && $self->{edit};
    $attributes //= {};

    my $object = $self->{object};
    #say STDERR "object ",$object->id;

    my $url = $self->{url}.'/'.$self->{lc_class};

    my @content = a(link => "Show all ".plural($self->class_name(undef, 'list')), url => plural($url));
    $url .= ':'.$object->id;
    if ($editable) {
        push @content, [1 => ' '], a(link => 'edit this one', url => $url.'?edit');
    }
    
    my @li = ([li => "id: ".$object->id], [li => "name: ".$object->name]);
    my $children_listers;
    $children_listers = $object->children_listers if $object->can('children_listers');
    # simple attributes:
    for my $a (sort keys %$attributes) {
        next if $a eq 'name';
        next if $children_listers->{$a};
        next if $attributes->{$a}{input} eq 'ignore';
        next if $attributes->{$a}{input} eq 'hidden';
        next if $attributes->{$a}{input} eq 'object' && !$object->$a;
        # todo what if style, ie object?
        my $v = $object->$a // '';
        if (ref $v) {
            for my $b (qw/name id data/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @li, [li => "$a: ".$v];
    }
    if ($object->can('info')) {
        my $info = $object->info($self);
        push @li, [li => $info] if $info;
    }
    # children, which can be 
    # open - there is $oids->[$oids_index], it opens an object, whose id is in what the method returns - or 
    # closed - otherwise
    # the method can be built-in (0), in result (1) or in result_set (2)
    for my $lister (sort keys %$children_listers) {
        my ($class_of_child, $lister_type, $editable) = @{$children_listers->{$lister}};
        say STDERR "class_of_child = $class_of_child, oid = ",($oids->[$oids_index+1] // 'undef') if $debug;
        $editable = 1 if !defined $editable; # todo make this more sensible
        $editable = $editable && $self->{edit};
        my %args = (url => $url, lc_class => $class_of_child, edit => $editable);
        $args{oid} = $oids->[$oids_index+1] 
            if defined $oids->[$oids_index+1] && $oids->[$oids_index+1] =~ /$class_of_child/;
        my $child = SmartSea::Object->new(\%args, $self);
        my $children;
        if ($lister_type == 2) {
            $children = [$self->{rs}->$lister($object)];
            my $name = $lister;
            $name =~ s/^(\w)/uc($1)/e;
            $child->set_class_name($name);
        } elsif ($lister_type) {
            $children = [$object->$lister($oids)];
        } else {
            $children = [$object->$lister()];
        }
        my $child_is_open = 0;
        if ($child->{object}) {
            for my $has_child (@$children) {
                if ($has_child->id == $child->{object}->id) {
                    $child_is_open = 1;
                    last;
                }
            }
        }
        say STDERR "child is open? $child_is_open" if $debug;
        if ($child_is_open) {
            push @li, [li => $child->li($oids, $oids_index+1)];
        } else {
            delete $child->{object};
            my %opt = (for_add => $self->for_child_form($lister, $children));
            push @li, [li => $child->li($oids, $oids_index+1, $children, \%opt)];
        }
    }
    
    return [[b => @content], [ul => \@li]];
}

sub item_class {
    my ($self, $parent, $children, $opt) = @_;
    $children = $self->all() unless $children;
    my $url = $self->{url}.'/'.$self->{lc_class};
    my $editable = $self->{edit};
        
    my @li;
    for my $obj (@$children) {
        my $name = $parent ?
            ($obj->can('name_with_parent') ? $obj->name_with_parent($parent->{object}) : $obj->name) :
            ($obj->can('long_name') ? $obj->long_name : $obj->name);
        my @content = a(link => $name, url => $url.':'.$obj->id);
        if ($editable) {
            push @content, [1 => ' '], a(link => 'edit', url => $url.':'.$obj->id.'?edit');
        }
        if ($self->{edit}) {
            my $source = $obj->result_source->source_name;
            my $name = $obj->name;
            my $onclick = "return confirm('Are you sure you want to delete $source '$name'?')";
            my %attr = (name => $obj->id, value => 'Remove', onclick => $onclick);
            push @content, [1 => ' '], button(%attr); # to do: remove or delete?
        }
        if ($self->{source} eq 'Dataset') {
            my @p;
            my $children_listers;
            $children_listers = $obj->children_listers if $obj->can('children_listers');
            for my $lister (sort keys %$children_listers) {
                my ($class_of_child, $lister_type, $editable) = @{$children_listers->{$lister}};
                my @parts = $obj->$lister;
                if (@parts) {
                    my $p = SmartSea::Object->new({lc_class => $class_of_child, edit => 0}, $self);
                    $p->set_class_name($lister);
                    push @p, $p->item_class($self, \@parts);
                }
            }
            if (@p) {
                push @content, [ul => \@p];
            }
        }
        push @li, [li => @content];
    }
    if ($self->{edit}) {
        my $can_add = 1;
        my $extra = 0;
        if ($opt && defined $opt->{for_add}) {
            if (ref $opt->{for_add}) {
                $extra = $opt->{for_add}
            } else {
                $can_add = 0 if $opt->{for_add} == 0;
            }
        }
        if ($can_add) {
            my @content;
            push @content, $extra, [0=>' '] if $extra;
            push @content, button(value => 'Add');
            push @li, [li => \@content] if @content;
        }
    }
    my $ul;
    if ($self->{edit}) {
        $ul = [form => {action => $url, method => 'POST'}, [ul => \@li]];
    } else {
        $ul = [ul => \@li];
    }
    return [[b => plural($self->class_name)], $ul];
}

sub for_child_form {
    my ($self, $lister, $children) = @_;
    if ($self->{object}->can('for_child_form')) {
        return $self->{object}->for_child_form($lister, $children, $self);
    }
}

sub form {
    my ($self, $oids, $oids_index, $parameters) = @_;
    say STDERR "form for $self->{source} (@$oids) $oids_index" if $debug;

    my $parent = $oids_index > 0 ? SmartSea::Object->new({oid => $oids->[$oids_index-1]}, $self) : undef;

    my $attributes = $self->attributes($parent);
    return unless $attributes;
    my @widgets;

    my $col_data = {};
    if ($self->{rs}->can('col_data_for_create')) {
        # these cannot be changed, so no widgets for these
        $col_data = $self->{rs}->col_data_for_create($parent->{object}, $parameters);
        for my $col (keys %$col_data) {
            push @widgets, hidden($col => $col_data->{$col});
        }
    }   

    # todo, what if there is no oids and this is a layer etc? bail out?
    my @doing;
    my $trace = '';
    if ($self->{object}) {
        @doing = ('Editing '.$self->class_name($parent),' in ');
        for (my $oid = 0; $oid < @$oids-1; ++$oid) {
            my $obj = SmartSea::Object->new({oid => $oids->[$oid]}, $self);
            $trace .= ' -> ' if $trace;
            $trace .= $obj->class_name.' '.$obj->{object}->name;
        }
        for my $key (keys %$attributes) {
            next if defined $col_data->{$key};
            next unless defined $self->{object}->$key;
            next if defined $parameters->{$key};
            $parameters->{$key} = $self->{object}->$key;
        }

        # todo: dataset have in-form button for computing min and max
        # that returns here and changes parameters
        # my $b = Geo::GDAL::Open($args{data_dir}.$self->path)->Band;
        #    $b->ComputeStatistics(0);
        #    $parameters->{min} = $b->GetMinimum;
        #    $parameters->{max} = $b->GetMaximum;
        
        push @widgets, hidden(id => $self->{object}->id); # should be in url...
        push @widgets, hidden(source => $self->{source});
    } else {
        my $what = title($attributes, $col_data, $self->{schema});
        @doing = ("Creating $what".$self->class_name($parent)," for ");
        my %from_upstream; # simple data from parent/upstream objects
        for (my $oid = 0; $oid < @$oids-1; ++$oid) {
            my $obj = SmartSea::Object->new({oid => $oids->[$oid]}, $self);
            $trace .= ' -> ' if $trace;
            $trace .= $obj->class_name.' '.$obj->{object}->name;
            for my $key (keys %$attributes) {
                next if defined $col_data->{$key};
                #next unless $obj->{object}->can($key);
                next unless $obj->{object}->attributes->{$key};
                say STDERR "getting $key from upstream $oids->[$oid]" if $debug;
                $from_upstream{$key} = $obj->{object}->$key;
            }
        }
        my $has_upstream;
        for my $key (keys %$attributes) {
            next if defined $parameters->{$key};
            next unless defined $from_upstream{$key};
            say STDERR "$key => $from_upstream{$key} is from upstream" if $debug;
            $has_upstream = 1;
            $parameters->{$key} = $from_upstream{$key};
        }
        push @widgets, [p => {style => 'color:red'}, 
                        'Filled data is from parent objects and for information only. '.
                        'Please delete or overwrite them.'] 
                            if $has_upstream;
    }
    my $p = $doing[0];
    $p .= $doing[1].$trace if $trace;
    push @widgets, [p => $p.'.'];
    push @widgets, widgets($attributes, $parameters, $self->{schema});
    push @widgets, button(value => 'Save'), [1 => ' '], button(value => 'Cancel');
    return @widgets;
}

sub title {
    my ($attributes, $parameters, $schema) = @_;
    for my $key (keys %$attributes) {
        my $a = $attributes->{$key};
        next unless $a->{input} eq 'ignore';
        next if $key =~ /2/; # hack to select layer_class from parameters
        say STDERR "$key $a->{class} $parameters->{$key}" if $debug;
        my $obj = $schema->resultset($a->{class})->single({id => $parameters->{$key}});
        return $obj->name.' ' if $obj;
    }
    return '';
}

sub singular {
    my ($w) = @_;
    if ($w =~ /ies$/) {
        $w =~ s/ies$/y/;
    } elsif ($w =~ /sses$/) {
        $w =~ s/sses$/ss/;
    } elsif ($w =~ /ss$/) {
    } else {
        $w =~ s/s$//;
    }
    return $w;
}

sub plural {
    my ($w) = @_;
    if ($w =~ /y$/) {
        $w =~ s/y$/ies/;
    } elsif ($w =~ /ss$/) {
        $w =~ s/ss$/sses/;
    } elsif ($w =~ /s$/) {
    } else {
        $w .= 's';
    }
    return $w;
}

1;
