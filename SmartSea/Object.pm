package SmartSea::Object;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use HTML::Entities qw/encode_entities_numeric/;
use Encode qw(decode encode);
use JSON;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

binmode STDERR, ":utf8";

# in args give oid or source, and possibly id (or search or object)
# polymorphic: returns the subclass object if this is one
sub new {
    my ($class, $args, $args2) = @_;
    my $self = {class_name => $args->{class_name}};
    for my $key (qw/schema edit debug sequences no_js/) {
        $self->{$key} = $args->{$key} // $args2->{$key};
    }
    for my $key (qw/url dbname user pass data_dir/) {
        $self->{$key} = $args->{$key} // $args2->{$key} // '';
    }
    if ($args->{oid}) {
        my ($source, $id) = split /:/, $args->{oid};
        $args->{id} = $id if defined $id;
        $self->{source} = $source;
    } elsif ($args->{source}) {
        $self->{source} = $args->{source};
    }
    $self->{source} = table2source($self->{source});
    say STDERR "new $self->{source} object, id=",(defined $args->{id} ? $args->{id} : 'undef') if $self->{debug};
    $self->{class} = 'SmartSea::Schema::Result::'.$self->{source};
    eval {
        $self->{rs} = $self->{schema}->resultset($self->{source});
        if ($args->{object}) { # do not use unless you know what you're doing
            $self->{object} = $args->{object};
        } elsif ($args->{search}) { # needed for getting a link object in some cases
            if ($self->{debug}) {
                for my $key (sort keys %{$args->{search}}) {
                    say STDERR "search term $key => $args->{search}{$key}";
                }
            }
            $self->{object} = $self->{rs}->single($args->{search});
        } elsif ($args->{id}) {
            
            #my %pk;
            #for my $pkey ($self->{rs}->result_source->primary_columns) {
            #    if ($pkey eq 'id') {
            #        $pk{id} = $id;
            #    } else {
            #        $pk{$pkey} = $self->{$pkey};
            #    }
            #    croak "pk $pkey not defined for a $self->{source}" unless defined $pk{$pkey};
            #}
            #$self->{object} = $self->{rs}->single(\%pk);
            
            # special case for rules, which have pk = id,cookie
            # prefer cookie = default, unless cookie given in args
            my @pk = $self->{class}->primary_columns;
            # todo: right now there is only one pk except for rules, which has two
            if ($self->{source} eq 'Rule') {
                for my $rule ($self->{rs}->search({id => $args->{id}})) {
                    if ($args->{cookie} && $rule->cookie ne DEFAULT) {
                        $self->{object} = $rule;
                        last;
                    }
                    $self->{object} = $rule;
                }
            } else {
                my $pk = $pk[0];
                $self->{object} = $self->{rs}->single({$pk => $args->{id}});
                
            }
            # is this in fact a subclass object?
            if ($self->{object} && $self->{object}->can('subclass')) {
                my $source = $self->{object}->subclass;
                if ($source) {
                    $self->{source} = $source;
                    $self->{class} = 'SmartSea::Schema::Result::'.$self->{source};
                    $self->{rs} = $self->{schema}->resultset($self->{source});
                    $self->{object} = $self->{rs}->single({super => $args->{id}});
                }
            }
        }
    };
    $self->{class_name} //= $self->{source};
    if ($@) {
        say STDERR "Error: $@" if $@;
        return undef;
    }
    bless $self, $class;
}

# parent can have children in many ways:
# parent <- link -> child # child can be a part of parent or independent
# parent -> object <- child # object can be a part of parent or independent
# parent <- child # child can be a part of parent or independent
# children_listers is a hash
# whose keys are object methods that return an array of children objects
# the values are hashes with keys
# for_child_form: subroutine which returns a widget for the child form
# source: the child source
# link_source: for many to many: the link source
# col: the column, which the result object of link_source knows and needs in order to return col data for create
#      needs to be something to be able to tell the link_source for create
# ref_to_me: the col referring to the parent (in link or child)
# self_ref: the col in the child, only the col needs to be set
# ref_to_child: the col referring to the child in link
sub children_listers {
    my ($self) = @_;
    return $self->{class}->children_listers if $self->{class}->can('children_listers');
    return {};
}

sub source_of_link {
    my $self = shift;
    my $listers = $self->children_listers;
    if (@_ == 1) {
        # this is for create, the source of the child
        my ($parameters) = @_;
        for my $lister (keys %$listers) {
            my $l = $listers->{$lister};
            return $l->{link_source} // $l->{source} if $parameters->{$l->{col}};
        }
    } elsif (@_ == 2) {
        # this is for delete, the source of the child and how to identify it
        my ($source_of_child, $child_id) = @_;
        for my $lister (keys %$listers) {
            my $l = $listers->{$lister};
            if ($source_of_child eq $l->{source}) {
                my $ref_to_me = $l->{ref_to_me} // $l->{self_ref};
                return unless defined $ref_to_me; # we already have the child
                return {
                    source => $l->{link_source} // $l->{source},
                    search => {
                        $ref_to_me => $self->{object}->id,
                        $l->{ref_to_child} // id => $child_id,
                    },
                    self_ref => $l->{self_ref}
                }
            }
        }
        return {source => $source_of_child, id => $child_id};
    }
}

sub superclass {
    my ($self) = @_;
    return $self->{class}->superclass if $self->{class}->can('superclass');
}

sub subclass {
    my ($self, $parameters) = @_;
    croak "Must have result object to call subclass." unless $self->{object};
    return $self->{object}->subclass($parameters) if $self->{object}->can('subclass');
}

sub need_form_for_child {
    my ($self, $child) = @_;
    return $self->{class}->need_form_for_child($child->{source}) if $self->{class}->can('need_form_for_child');
    return 1;
}

sub col_data_for_create {
    my ($self, $parent, $parameters) = @_;
    return $self->{class}->col_data_for_create($parent->{object}, $parameters) 
        if $self->{class}->can('col_data_for_create');
    return {};
}

sub attributes {
    my ($self, $parent) = @_;
    return {} unless $self->{class}->can('attributes');
    return $self->{class}->attributes($parent->{object}) unless $self->{object};
    return $self->{object}->attributes($parent->{object});
}

sub simple_attribute_values {
    my ($self, $parent) = @_;
    my $attributes = $self->attributes($parent);
    my $children_listers = $self->children_listers;
    my $object = $self->{object};
    my %a;
    for my $a (sort keys %$attributes) {
        next if $a eq 'id';
        next if $a eq 'name';
        next if $a eq 'super';
        next if $children_listers->{$a};
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
        $a{$a} = $v;
    }
    my $superclass = $self->superclass;
    if ($superclass) {
        # subclass attributes have preference
        my $super = SmartSea::Object->new({source => $superclass, object => $object->super}, $self);
        %a = (%{$super->simple_attribute_values($parent)}, %a);
    }
    return \%a;
}

# link an object to an object
sub link {
    my ($self, $oids, $parameters) = @_;
      
    my $parent = $oids->has_prev ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;
    
    unless ($parent && $parent->{object}) {
        my $error = "Can't create link: parent missing.";
        croak $error;
    }
    
    say STDERR "create a link from $parent->{source} to $self->{source}" if $self->{debug};
        
    # the actual link object to create
    $self = SmartSea::Object->new({source => $parent->source_of_link($parameters)}, $self);
    my $col_data = $self->col_data_for_create($parent, $parameters);
    if ($self->{debug} > 1) {
        for my $col (sort keys %$col_data) {
            say STDERR "  $col => ",(defined $col_data->{$col} ? $col_data->{$col} : 'undef');
        }
    }
    $self->{rs}->create($col_data);
}

sub update_or_create {
    my ($self, $oids, $parameters) = @_;
    if ($self->{object}) {
        $self->update($oids, $parameters);
    } else {
        $self->create($oids, $parameters);
    }
}

sub create {
    my ($self, $oids, $parameters) = @_;
    say STDERR "create a $self->{source}" if $self->{debug};

    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;
    
    my $attributes = $self->attributes;
    my $col_data = $self->col_data_for_create($parent, $parameters);

    # create embedded child objects
    # the child does not exist on its own nor can be used by other objects (composition)
    for my $attr (keys %$attributes) {
        next unless $attributes->{$attr}{input} eq 'object';
        if (!$attributes->{$attr}{required} && !$parameters->{$attr.'_is'}) {
            $col_data->{$attr} = undef;
            next;
        }
        my $child = SmartSea::Object->new({source => $attributes->{$attr}{source}}, $self);
        # how to consume child parameters and possibly know them from our parameters?
        $child->create($oids, $parameters);
        $col_data->{$attr} = $child->{object}->id;
    }
    # collect creation data from input
    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        next unless exists $parameters->{$col};
        next if $parameters->{$col} eq '' && $attributes->{$col}{empty_is_default};
        $col_data->{$col} = $parameters->{$col} if exists $parameters->{$col};
        $col_data->{$col} = undef if $attributes->{$col}{empty_is_null} && $col_data->{$col} eq '';
    }
    # 
    if ($self->{class}->can('is_ok')) {
        my $error = $self->{class}->is_ok($col_data);
        croak $error if $error;
    }
    if (!$self->{sequences} && $self->{rs}->result_source->has_column('id')) {
        # this is probably only in tests, sqlite does not have sequences
        my $id = 1;
        for my $row ($self->{rs}->all) {
            $id = $row->id + 1 if $id <= $row->id;
        }
        $col_data->{id} = $id;
    }
    for my $col (sort keys %$col_data) {
        say STDERR "  $col => ",(defined $col_data->{$col} ? $col_data->{$col} : 'undef') if $self->{debug} > 1;
    }
    $self->{object} = $self->{rs}->create($col_data); # or add_to_x??
    my $id = $self->{object}->id;
    $id = $id->id if ref $id;
    say STDERR "id of the new $self->{source} is ",$id if $self->{debug};
    # add links to parents?

    # make subclass object?
    my $class = $self->subclass($parameters);
    if ($class) {
        say STDERR "Create $class subclass object with id $id" if $self->{debug};
        my $obj = SmartSea::Object->new({source => $class}, $self);
        $parameters->{super} = $id;
        $obj->create($oids, $parameters);
    }
}

sub update {
    my ($self, $oids, $parameters) = @_;

    say STDERR "update $self->{source} ",$self->{object}->id if $self->{debug};
    if ($self->{debug} && $self->{debug} > 1) {
        for my $param (sort keys %$parameters) {
            say STDERR "  param $param => ",(defined $parameters->{$param} ? $parameters->{$param} : 'undef');
        }
    }
    
    my $attributes = $self->attributes;
    my $col_data = {};

    # create, update or delete embedded child objects
    my %delete;
    for my $attr (keys %$attributes) {
        next unless $attributes->{$attr}{input} eq 'object';
        if ($attributes->{$attr}{required}) {
            my $child = $self->{object}->$attr;
            $child = SmartSea::Object->new({source => $attributes->{$attr}{source}, object => $child}, $self);
            $child->update($oids, $parameters);
        } elsif ($parameters->{$attr.'_is'}) {
            # todo: child attributes are now in parameters and may mix with parameters for self
            my $child = $self->{object}->$attr;
            unless ($child) {
                $child = SmartSea::Object->new({source => $attributes->{$attr}{source}}, $self);
                $child->create($oids, $parameters);
                $col_data->{$attr} = $child->{object}->id;
            } else {
                $child = SmartSea::Object->new({source => $attributes->{$attr}{source}, object => $child}, $self);
                $child->update($oids, $parameters);
            }
        } else {
            $col_data->{$attr} = undef;
            if (my $child = $self->{object}->$attr) {
                $delete{$attr} = $child; # todo: make child SmartSea::Object
            }
        }
    }

    # collect update data from input
    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        next unless exists $parameters->{$col};
        # todo: $parameters->{$col} may be undef?
        next if $parameters->{$col} eq '' && $attributes->{$col}{empty_is_default};
        $col_data->{$col} = $parameters->{$col} if exists $parameters->{$col};
        $col_data->{$col} = undef if $attributes->{$col}{empty_is_null} && $col_data->{$col} eq '';
    }

    if ($self->{class}->can('is_ok')) {
        my $error = $self->{class}->is_ok($col_data);
        croak $error if $error;
    }

    if ($self->{debug} && $self->{debug} > 1) {
        for my $col (sort keys %$col_data) {
            say STDERR "  $col => ",(defined $col_data->{$col} ? $col_data->{$col} : 'undef');
        }
    }
    $self->{object}->update($col_data);

    # delete children:
    for my $class_of_child (keys %delete) {
        $delete{$class_of_child}->delete;
    }

    # update superclass:
    my $superclass = $self->superclass;
    if ($superclass) {
        my $super = SmartSea::Object->new({source => $superclass, object => $self->{object}->super}, $self);
        $super->update($oids, $parameters);
    }
    
}

# delete an object or remove the link
sub delete {
    my ($self, $oids, $parameters) = @_;
    
    say STDERR "delete $self->{source}" if $self->{debug};

    # is it actually a link that needs to be deleted?
    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;
    if ($parent) {
        # we need the object which links parent to self
        my $args = $parent->source_of_link($self->{source}, $parameters->{id});
        if ($args) {
            if ($args->{self_ref}) {
                eval {
                    $self->{object}->update({$args->{self_ref} => undef});
                };
                say STDERR "Error: $@" if $@;
                return "$@";
            }
            delete $args->{self_ref};
            $self = SmartSea::Object->new($args, $self);
            say STDERR "actually, delete $self->{source}" if $self->{debug};
        }
    }
    
    unless ($self->{object}) {
        my $error = "Could not find the requested $self->{source}.";
        say STDERR "Error: $error";
        return $error;
    }
    
    my $attributes = $self->attributes;
    my %delete;
    for my $attr (keys %$attributes) {
        if ($attributes->{$attr}{input} eq 'object') {
            my $child = $self->{object}->$attr;
            next unless $child;
            $delete{$attributes->{$attr}{source}} = $child->id;
        }
    }
    $self->{object}->delete;

    # delete children:
    for my $source (keys %delete) {
        my %args = (source => $source, id => $delete{$source});
        my $child = SmartSea::Object->new(\%args, $self);
        $child->delete;
    }

    # delete superclass:
    my $superclass = $self->superclass;
    if ($superclass) {
        my $super = SmartSea::Object->new({source => $superclass, object => $self->{object}->super}, $self);
        $super->delete($oids, $parameters);
    }
}

sub all {
    my ($self) = @_;
    return [$self->{rs}->list] if $self->{rs}->can('list');
    # todo: use self->rs and methods in it below
    my $col;
    for my $c (qw/name id super/) {
        if ($self->{rs}->result_source->has_column($c)) {
            $col = $c;
            last;
        }
    }
    my $order_by = $self->{class}->can('order_by') ? $self->{class}->order_by : {-asc => $col};
    return [$self->{rs}->search(undef, {order_by => $order_by})->all];
}

# return object as an item for HTML lists
sub item {
    my ($self, $oids, $children, $opt) = @_;
    say STDERR "item for $self->{source}" if $self->{debug};

    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;

    $opt->{editable_children} = $self->{edit} unless defined $opt->{editable_children};

    my $object = $self->{object};
    
    return $self->item_class($parent, $children, $opt) unless $object;

    say STDERR "object ",$object->id if $self->{debug};
    
    my $url = $self->{url}.'/'.source2table($self->{source});

    my @content = a(link => "Show all ".plural($self->{class_name}), url => plural($url));
    $url .= ':'.$object->id;
    push @content, [1 => ' '], a(link => 'edit this one', url => $url.'?edit') if $self->{edit};
    
    my @li = ([li => "id: ".$object->id], [li => "name: ".encode_entities_numeric($object->name)]);

    my $attributes = $self->simple_attribute_values($parent);
    for my $a (sort keys %$attributes) {
        push @li, [li => "$a: ".encode_entities_numeric($attributes->{$a})];
    }
    
    if ($object->can('info')) {
        my $info = $object->info($self);
        push @li, [li => $info] if $info;
    }
    
    for my $item ($self->children_items($url, $oids)) {
        push @li, $item;
    }
    
    return [[b => @content], [ul => \@li]];
}

# return children items, 
# children are listed by the result method children_listers
sub children_items {
    my ($self, $url, $oids) = @_;
    my $next = ($oids && $oids->has_next) ? $oids->next : undef;
    # children can be open or closed
    # open if there is $next whose source is what children lister tells
    # TODO: what if there are more than one children with the same source?
    my @items;
    my $children_listers = $self->children_listers;
    for my $lister (sort keys %$children_listers) {
        my %args = %{$children_listers->{$lister}};
        my $editable_children = $self->{edit};
        $editable_children = 0 if exists $args{editable_children} && $args{editable_children} == 0;
        say STDERR "$lister, children: source = $args{source}, child oid = ",($next // 'undef') if $self->{debug};
        $args{url} = $url;
        if (defined $next) {
            my ($table, $id) = split /:/, $next;
            if (table2source($table) eq $args{source}) {
                $args{id} = $id;
            }
        }
        my $child = SmartSea::Object->new(\%args, $self);
        my $children = [$self->{object}->$lister];
        next if @$children == 1 && !$children->[0];
        my $child_is_open = 0;
        if ($child->{object}) {
            for my $has_child (@$children) {
                say STDERR "has child: ",$has_child->id if $self->{debug} > 1;
                if ($has_child->id == $child->{object}->id) {
                    $child_is_open = 1;
                    last;
                }
            }
        }
        say STDERR "child is open? $child_is_open" if $self->{debug};
        if ($child_is_open) {
            $child->{edit} = 0 unless $editable_children;
            push @items, [li => $child->item($oids->with_index('next'))];
        } else {
            delete $child->{object};
            my %opt = (
                for_add => $children_listers->{$lister}{for_child_form}->($self, $children),
                editable_children => $editable_children,
                cannot_add_remove_children => $children_listers->{$lister}{cannot_add_remove_children},
                button => $children_listers->{$lister}{child_is_mine} ? 'Create' : 'Add',
                );
            push @items, [li => $child->item_class($self, $children, \%opt)];
        }
    }
    my $superclass = $self->superclass;
    if ($superclass) {
        my $super = SmartSea::Object->new(
            {
                source => $superclass, 
                object => $self->{object}->super
            }, $self);
        push @items, $super->children_items($url, $oids);
    }
    return @items;
}

sub item_class {
    my ($self, $parent, $children, $opt) = @_;
    $children = $self->all() unless $children;
    my $url = $self->{url}.'/'.source2table($self->{source});
        
    my @li;
    for my $obj (@$children) {
        $obj->{name} = $obj->name;
    }
    for my $obj (sort {$a->{name} cmp $b->{name}} @$children) {
        my @content = a(link => $obj->{name}, url => $url.':'.$obj->id);
        if ($opt->{editable_children}) {
            push @content, [1 => ' '], a(link => 'edit', url => $url.':'.$obj->id.'?edit');
        }
        if ($self->{edit} && !$opt->{cannot_add_remove_children}) {
            my $source = $obj->result_source->source_name;
            my $name = '"'.$obj->{name}.'"';
            $name =~ s/'//g;
            $name = encode_entities_numeric($name);
            my $onclick = $parent ?
                "return confirm('Are you sure you want to remove the link to $source $name?')" :
                "return confirm('Are you sure you want to delete the $source $name?')";
            my $value = $parent ? 'Remove' : 'Delete';
            my %attr = (name => $obj->id, value => $value);
            $attr{onclick} = $onclick unless $self->{no_js};
            push @content, [1 => ' '], button(%attr); # to do: remove or delete?
        }
        if ($self->{source} eq 'Dataset') {
            my @p;
            my $children_listers = $self->children_listers;
            for my $lister (sort keys %$children_listers) {
                my @parts = $obj->$lister;
                if (@parts) {
                    my %args = %{$children_listers->{$lister}};
                    $args{edit} = 0;
                    my $p = SmartSea::Object->new(\%args, $self);
                    push @p, [li => $p->item_class($self, \@parts, {editable_children => $opt->{editable_children}})];
                }
            }
            if (@p) {
                push @content, [ul => \@p];
            }
        }
        push @li, [li => @content];
    }
    if ($self->{edit} && !$opt->{cannot_add_remove_children}) {
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
            push @content, button(value => $opt->{button} // 'Create');
            push @li, [li => \@content] if @content;
        }
    }
    my $ul;
    if ($self->{edit}) {
        $ul = [form => {action => $url, method => 'POST'}, [ul => \@li]];
    } else {
        $ul = [ul => \@li];
    }
    return [[b => plural($self->{class_name})], $ul];
}

sub form {
    my ($self, $oids, $parameters) = @_;
    say STDERR "form for $self->{source}" if $self->{debug};

    my $parent = $oids->has_prev ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;

    # is this ok?
    return if $parent && !$parent->need_form_for_child($self);
    say STDERR "form is needed" if $self->{debug};

    my $attributes = $self->attributes($parent);
    my @widgets;
    my $title = ($self->{object} ? 'Editing ' : 'Creating ');
    $title .= $self->{source};
    push @widgets, [p => $title];

    my $col_data = $self->col_data_for_create($parent, $parameters);
    for my $col (keys %$col_data) {
        next unless defined $col_data->{$col};
        my $rs = $self->{schema}->resultset($attributes->{$col}{source});
        my $val = $rs->single({id => $col_data->{$col}})->name;
        push @widgets, [p => [1 => "$col: $val"]];
        push @widgets, hidden($col => $col_data->{$col});
        delete $attributes->{$col};
    }

    # todo, what if there is no oids and this is a layer etc? bail out?
    if ($self->{object}) {
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
        my %from_upstream; # simple data from parent/upstream objects
        for my $id (0..$oids->count-2) {
            my $obj = SmartSea::Object->new({oid => $oids->at($id)}, $self);
            for my $key (keys %$attributes) {
                next if defined $col_data->{$key};
                next unless $obj->{object}->attributes->{$key};
                say STDERR "getting $key from upstream" if $self->{debug};
                $from_upstream{$key} = $obj->{object}->$key;
            }
        }
        my $has_upstream;
        for my $key (keys %$attributes) {
            next if defined $parameters->{$key};
            next unless defined $from_upstream{$key};
            say STDERR "$key => $from_upstream{$key} is from upstream" if $self->{debug};
            $has_upstream = 1;
            $parameters->{$key} = $from_upstream{$key};
        }
        push @widgets, [p => {style => 'color:red'}, 
                        'Filled data is from parent objects and for information only. '.
                        'Please delete or overwrite them.'] 
                            if $has_upstream;
    }
    push @widgets, widgets($attributes, $parameters, $self->{schema});
    push @widgets, button(value => 'Save'), [1 => ' '], button(value => 'Cancel');
    return @widgets;
}

1;
