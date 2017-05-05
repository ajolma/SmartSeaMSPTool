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

# in args give oid or object, or source and possibly id or search
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
    } elsif (defined $args->{object}) {
        $self->{object} = $args->{object};
        $self->{class} = ref $self->{object}; # class = result_source
        # $self->{schema} = $self->{class}->schema;
        ($self->{source}) = $self->{class} =~ /(\w+)$/;
        $self->{class_name} //= $self->{source};
        # $self->{rs} = $self->{class}->resultset; # rs = resultset
        $self->{rs} = $self->{schema}->resultset($self->{source});
        return bless $self, $class;
    } elsif ($args->{source}) {
        $self->{source} = $args->{source};
    } 
    $self->{source} = table2source($self->{source});
    say STDERR "new $self->{source} object, id=",(defined $args->{id} ? $args->{id} : 'undef') if $self->{debug};
    $self->{class} = 'SmartSea::Schema::Result::'.$self->{source};
    eval {
        $self->{rs} = $self->{schema}->resultset($self->{source});
        if ($args->{search}) { # needed for getting a link object in some cases
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

            # todo: this assumes first pk is id (maybe not named 'id' but anyway)
            my @pk = $self->{class}->primary_columns;
            if (@pk == 1) {
                @pk = ($args->{id});
            } elsif (@pk == 2) {
                # special case for rules, which have pk = id,cookie
                # 'find' of ResultSet for Rule is also replaced by 'my_find' to return default by default
                @pk = ($args->{id}, $args->{cookie});
            } else {
                die "$self->{class}: more than two primary keys!";
            }
            $self->{object} = $self->{rs}->can('my_find') ? 
                $self->{rs}->my_find(@pk) : $self->{rs}->find(@pk);
            say STDERR "object: ",($self->{object} // 'undef') if $self->{debug} && $self->{debug} > 1;
            
            # is this in fact a subclass object?
            if ($self->{object} && $self->{object}->can('subclass')) {
                my $source = $self->{object}->subclass;
                if ($source) {
                    my $object = $self->{schema}->resultset($source)->single({super => $args->{id}});
                    if ($object) {
                        # ok
                        $self->{source} = $source;
                        $self->{class} = 'SmartSea::Schema::Result::'.$self->{source};
                        $self->{rs} = $self->{schema}->resultset($source);
                        $self->{object} = $object;
                        say STDERR $self->{object} if $self->{debug} && $self->{debug} > 1;
                    } else {
                        say STDERR "Error in db, missing subclass object for $self->{source}:$args->{id}";
                    }
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

sub next_id {
    my $self = shift;
    # this is probably needed only in tests, sqlite does not have sequences
    my $id = 1;
    for my $row ($self->{rs}->all) {
        $id = $row->id + 1 if $id <= $row->id;
    }
    return $id;
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

sub super {
    my ($self) = @_;
    my $class = $self->superclass;
    return unless $class && $self->{object};
    my $super = $self->{object}->super;
    return unless $super;
    return SmartSea::Object->new({ object => $super }, $self) if $class;
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

sub recursive_column_value {
    my ($self, $column) = @_;
    return $self->{object}->$column if $self->{object}->can($column);
    my $super = $self->super;
    return $super->recursive_column_value($column) if $super;
}

sub column_values_from_context {
    my ($self, $parent, $parameters) = @_;
    return {} unless $self->{class}->can('column_values_from_context');
    return {} unless $parent && $parent->{object};
    return $self->{class}->column_values_from_context($parent->{object}, $parameters);
}

sub recursive_column_values_from_context {
    my ($self, $parent, $parameters) = @_;
    my $data = $self->column_values_from_context($parent, $parameters);
    my $super = $self->super;
    if ($super) {
        my $from_super = $super->recursive_column_values_from_context($parent, $parameters);
        %$data = (%$from_super, %$data);
    }
    return $data;
}

sub columns {
    my ($self, $parent) = @_;
    if ($self->{class}->can('context_based_columns')) {
        my $who = $self->{object} // $self->{class};
        my $parent_object = ($parent && $parent->{object}) ? $parent->{object} : undef;
        my ($columns, $columns_info) = $who->context_based_columns($parent_object);
        return $columns_info;
    } else {
        return $self->{class}->columns_info;
    }
}

sub recursive_columns {
    my ($self, $parent) = @_;
    my $data = $self->columns($parent);
    my $super = $self->super;
    if ($super) {
        my $from_super = $super->recursive_columns($parent);
        %$data = (%$from_super, %$data);
    }
    return $data;
}

sub simple_column_values {
    my ($self, $parent) = @_;
    my $columns = $self->columns($parent);
    my $children_listers = $self->children_listers;
    my $object = $self->{object};
    my %values;
    for my $col (sort keys %$columns) {
        next if $col eq 'id';
        next if $col eq 'name';
        next if $col eq 'super';
        next if $children_listers->{$col};
        next if $columns->{$col}{is_foreign_key} && $columns->{$col}{is_composition} && !$object->$col;
        # todo what if style, ie object?
        my $v = $object->$col // '';
        if (ref $v) {
            for my $b (qw/name id data/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        $values{$col} = $v;
    }
    my $super = $self->super;
    # subclass columns have preference
    %values = (%{$super->simple_column_values($parent)}, %values) if $super;
    return \%values;
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
    my $col_data = $self->column_values_from_context($parent, $parameters);
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
    
    my $columns = $self->columns($parent);
    my $col_data = $self->column_values_from_context($parent, $parameters);

    # collect creation data from input
    for my $col (keys %$columns) {
        if ($columns->{$col}{is_composition}) {
            if (!$columns->{$col}{required} && !$parameters->{$col.'_is'}) {
                $col_data->{$col} = undef;
            } else {
                # create embedded child objects
                # the child does not exist on its own nor can be used by other objects (composition)
                my $child = SmartSea::Object->new({source => $columns->{$col}{source}}, $self);
                # TODO: child parameters should be prefixed with child name
                $child->create($oids, $parameters);
                $col_data->{$col} = $child->{object}->id;
            }
        } else {
            next unless exists $parameters->{$col};
            next unless defined $parameters->{$col};
            next if $parameters->{$col} eq '' && $columns->{$col}{empty_is_default};
            $col_data->{$col} = $parameters->{$col};
            $col_data->{$col} = undef if $columns->{$col}{empty_is_null} && $col_data->{$col} eq '';
        }
    } 
    if ($self->{class}->can('is_ok')) {
        my $error = $self->{class}->is_ok($col_data);
        croak $error if $error;
    }
    $col_data->{id} = $self->next_id if !$self->{sequences} && $self->{rs}->result_source->has_column('id');
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
    
    my $columns = $self->columns;
    my $col_data = {};

    # create, update or delete embedded child objects
    my %delete;
    for my $col (keys %$columns) {
        next unless $columns->{$col}{is_composition};
        if ($columns->{$col}{required}) {
            my $child = $self->{object}->$col;
            $child = SmartSea::Object->new({object => $child}, $self);
            $child->update($oids, $parameters);
        } elsif ($parameters->{$col.'_is'}) {
            # TODO: child parameters should be prefixed with child name
            my $child = $self->{object}->$col;
            unless ($child) {
                $child = SmartSea::Object->new({source => $columns->{$col}{source}}, $self);
                $child->create($oids, $parameters);
                $col_data->{$col} = $child->{object}->id;
            } else {
                $child = SmartSea::Object->new({object => $child}, $self);
                $child->update($oids, $parameters);
            }
        } else {
            $col_data->{$col} = undef;
            if (my $child = $self->{object}->$col) {
                $delete{$col} = $child; # todo: make child SmartSea::Object
            }
        }
    }

    # collect update data from input
    for my $col (keys %$columns) {
        next if $columns->{$col}{is_composition};
        next unless exists $parameters->{$col};
        # todo: $parameters->{$col} may be undef?
        next if $parameters->{$col} eq '' && $columns->{$col}{empty_is_default};
        $col_data->{$col} = $parameters->{$col} if exists $parameters->{$col};
        $col_data->{$col} = undef if $columns->{$col}{empty_is_null} && $col_data->{$col} eq '';
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
    my $super = $self->super;
    $super->update($oids, $parameters) if $super;
    
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
    
    my $columns = $self->columns;
    my %delete;
    for my $col (keys %$columns) {
        if ($columns->{$col}{is_foreign_key} && $columns->{$col}{is_composition}) {
            my $child = $self->{object}->$col;
            next unless $child;
            $delete{$columns->{$col}{source}} = $child->id;
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
    my $super = $self->super;
    $super->delete($oids, $parameters) if $super;
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
    $opt //= {};
    say STDERR "item for $self->{source}" if $self->{debug};

    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;

    $opt->{editable_children} = $self->{edit} unless defined $opt->{editable_children};

    my $object = $self->{object};
    
    return $self->item_class($parent, $children, $opt) unless $object;

    say STDERR "object ",$object->id if $self->{debug};

    my $source = $self->superclass // $self->{source};
    my $url = $self->{url}.'/'.source2table($source);

    my @content;
    if ($opt->{composed}) {
        @content = ([1 => $self->{source}]);
        $url .= ':'.$object->id;
    } else {
        @content = a(link => "Show all ".plural($self->{class_name}), url => plural($url));
        $url .= ':'.$object->id;
        push @content, [1 => ' '], a(link => 'edit this one', url => $url.'?edit') if $self->{edit};
    }
    
    my @li = ([li => "id: ".$object->id], [li => "name: ".encode_entities_numeric($object->name)]);

    my $values = $self->simple_column_values($parent);
    for my $col (sort keys %$values) {
        push @li, [li => "$col: ".encode_entities_numeric($values->{$col})];
    }

    push @li, $self->composed_object_items($parent, $oids, $children, $opt);
    
    if ($object->can('info')) {
        my $info = $object->info($self);
        push @li, [li => $info] if $info;
    }
    
    push @li, $self->children_items($url, $oids);
    
    return [[b => @content], [ul => \@li]];
}

sub composed_object_items {
    my ($self, $parent, $oids, $children, $opt) = @_;
    my $super = $self->super;
    my @items;
    @items = $super->composed_object_items($parent, $oids, $children, $opt) if $super;
    my $columns = $self->columns($parent);
    for my $col (sort keys %$columns) {
        next unless $columns->{$col}{is_composition};
        my $composed = $self->{object}->$col;
        next unless $composed;
        my $obj = SmartSea::Object->new({object => $composed}, $self);
        my %opt = %$opt;
        $opt{composed} = 1;
        push @items, [li => $obj->item($oids, $children, \%opt)];
    }
    return @items;
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
        my $args = $children_listers->{$lister};
        my %args = %$args;
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
            say STDERR scalar(@$children)," children" if $self->{debug};
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
            push @items, [li => $child->item($oids->with_index('next'), [], {})];
        } else {
            delete $child->{object};
            my $for_add = $args->{for_child_form}->($self, $children) if $args->{for_child_form};
            my %opt = (
                for_add => $for_add,
                editable_children => $editable_children,
                cannot_add_remove_children => $args->{cannot_add_remove_children},
                button => $args->{child_is_mine} ? 'Create' : 'Add',
                );
            push @items, [li => $child->item_class($self, $children, \%opt)];
        }
    }
    my $super = $self->super;
    push @items, $super->children_items($url, $oids) if $super;
    return @items;
}

sub item_class {
    my ($self, $parent, $children, $opt) = @_;
    $children = $self->all() unless $children;
    my $url = $self->{url}.'/'.source2table($self->{source});
        
    my @li;
    for my $obj (@$children) {
        my @content = a(link => $obj->name, url => $url.':'.$obj->id);
        if ($opt->{editable_children}) {
            push @content, [1 => ' '], a(link => 'edit', url => $url.':'.$obj->id.'?edit');
        }
        if ($self->{edit} && !$opt->{cannot_add_remove_children}) {
            my $source = $obj->result_source->source_name;
            my $name = '"'.$obj->name.'"';
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
                    push @p, [
                        li => $p->item_class($self, \@parts, {editable_children => $opt->{editable_children}})
                    ];
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

    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self) : undef;

    # is this ok?
    return if $parent && !$parent->need_form_for_child($self);
    say STDERR "form is needed" if $self->{debug};

    # TODO: child columns are now in parameters and may mix with parameters for self

    my $columns = $self->recursive_columns($parent);
    my @widgets;
    my $title = $self->{object} ? 'Editing ' : 'Creating ';
    $title .= $self->{object} ? $self->{object}->name : $self->{source};
    push @widgets, [p => $title];

    # if the form is in the context of a parent
    my %skip;
    my $col_data = $self->recursive_column_values_from_context($parent, $parameters);
    for my $col (keys %$col_data) {
        next unless defined $col_data->{$col};
        my $val = $self->{schema}->
            resultset($columns->{$col}{source})->
            single({id => $col_data->{$col}})->name;
        push @widgets, [p => [1 => "$col: $val"]];
        push @widgets, hidden($col => $col_data->{$col});
        delete $columns->{$col};
        $skip{$col} = 1;
    }

    # obtain default values for widgets
    # todo, what if there is no oids and this is a layer etc? bail out?
    if ($self->{object}) {
        # edit
        for my $col (keys %$columns) {
            next if defined $col_data->{$col};
            next if defined $parameters->{$col};
            my $val = $self->recursive_column_value($col);
            next unless defined $val;
            $parameters->{$col} = $val;
        }

        # todo: dataset have in-form button for computing min and max
        # that returns here and changes parameters
        # my $b = Geo::GDAL::Open($args{data_dir}.$self->path)->Band;
        #    $b->ComputeStatistics(0);
        #    $parameters->{min} = $b->GetMinimum;
        #    $parameters->{max} = $b->GetMaximum;

    } else {
        # create
        my %from_upstream; # simple data from parent/upstream objects
        for my $id (0..$oids->count-2) {
            my $obj = SmartSea::Object->new({oid => $oids->at($id)}, $self);
            for my $key (keys %$columns) {
                next if defined $col_data->{$key};
                next unless $obj->{object}->columns->{$key};
                say STDERR "getting $key from upstream" if $self->{debug};
                $from_upstream{$key} = $obj->{object}->$key;
            }
        }
        my $has_upstream;
        for my $key (keys %$columns) {
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
    my $super = $self->super;
    push @widgets, [
        fieldset => [[legend => $super->{source}], $super->widgets($parent, $parameters, \%skip)]
    ] if $super;
    push @widgets, $self->widgets($parent, $parameters, \%skip);
    push @widgets, button(value => 'Save'), [1 => ' '], button(value => 'Cancel');
    return [fieldset => [[legend => $self->{source}], @widgets]];
}

sub widgets {
    my ($self, $parent, $values, $skip) = @_;
    my $schema = $self->{schema};
    my @fcts;
    my @form;
    my $columns_info;
    my @columns;
    if ($self->{class}->can('context_based_columns')) {
        my $who = $self->{object} // $self->{class};
        my $parent_object = ($parent && $parent->{object}) ? $parent->object : undef;
        my $columns;
        ($columns, $columns_info) = $who->context_based_columns($parent_object);
        @columns = @$columns;
    } else {
        # standard DBIx
        $columns_info = $self->{class}->columns_info;
        @columns = $self->{class}->columns;
    }
    for my $col (@columns) {
        next if $skip->{$col};
        my $info = $columns_info->{$col};
        my $input;
        for my $info_text (qw/data_type html_input/) {
            $info->{$info_text} = '' unless $info->{$info_text};
        }
        if ($info->{data_type} eq 'text') {
            $input = text_input(
                name => $col,
                size => ($info->{html_size} // 10),
                value => $values->{$col} // ''
            );
        } elsif ($info->{data_type} eq 'textarea') {
            $input = textarea(
                name => $col,
                rows => $info->{rows},
                cols => $info->{cols},
                value => $values->{$col} // ''
            );
        } elsif ($info->{is_foreign_key} && !$info->{is_composition}) {
            my $objs;
            if (ref $info->{objs} eq 'ARRAY') {
                $objs = $info->{objs};
            } elsif (ref $info->{objs} eq 'CODE') {
                $objs = [];
                for my $obj ($schema->resultset($info->{source})->all) {
                    if ($info->{objs}->($obj)) {
                        push @$objs, $obj;
                    }
                }
            } elsif ($info->{objs}) {
                $objs = [$schema->resultset($info->{source})->search($info->{objs})];
            } else {
                $objs = [$schema->resultset($info->{source})->all];
            }
            my $id;
            if ($values->{$col}) {
                if (ref $values->{$col}) {
                    $id = $values->{$col}->id;
                } else {
                    $id = $values->{$col};
                }
            }
            $input = drop_down(
                name => $col,
                objs => $objs,
                selected => $id,
                values => $info->{values},
                allow_null => $info->{allow_null}
            );
        } elsif ($info->{html_input} eq 'checkbox') {
            $input = checkbox(
                name => $col,
                visual => $info->{cue},
                checked => $values->{$col}
            );
        } elsif ($info->{html_input} eq 'spinner') {
            $input = spinner(
                name => $col,
                min => $info->{min},
                max => $info->{max},
                value => $values->{$col} // 1
            );
        }
        if ($info->{is_composition}) {
            unless ($info->{required}) {
                my $fct = $col.'_fct';
                my $cb = $col.'_cb';
                push @form, [ p => checkbox(
                                  name => $col.'_is',
                                  visual => "Define ".$info->{source},
                                  checked => $values->{$col},
                                  id => $cb )
                ];
                my $code =<< "END_CODE";
function $fct() {
  var cb = document.getElementById("$cb");
  var id = "$col";
  if (!cb.checked) {
    document.getElementById(id).style.display=(cb.checked)?'':'none';
  }
  cb.addEventListener("change", function() {
    document.getElementById(id).style.display=(this.checked)?'':'none';
  }, false);
};
END_CODE
                push @form, [script => $code];
                push @fcts, "\$(document).ready($fct);";
            } else {
                push @form, hidden($col.'_is', 1);
            }
            my $composed = SmartSea::Object->new({source => $info->{source}, object => $values->{$col}}, $self);
            my @style = $composed->widgets(undef, $values);
            push @form, [fieldset => [[legend => $composed->{source}], @style]];
        } else {
            push @form, [ p => [[1 => "$col: "], $input] ] if $input;
        }
    }
    if (@fcts) {
        push @form, [script => {src=>"http://code.jquery.com/jquery-1.10.2.js"}, ''];
        push @form, [script => join("\n",@fcts)];
    }
    return @form;
}

1;
