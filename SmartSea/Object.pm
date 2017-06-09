package SmartSea::Object;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Scalar::Util qw(weaken);
use HTML::Entities qw/encode_entities_numeric/;
use Encode qw(decode encode);
use JSON;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

use Data::Dumper;

binmode STDERR, ":utf8";

# in args give oid or object, or source and possibly id or search
# polymorphic: returns the subclass object if this is one
sub new {
    my ($class, $args, $client) = @_;
    my $self = {class_name => $args->{class_name}, client => $client};
    if ($args->{oid}) {
        my ($source, $id) = split /:/, $args->{oid};
        $args->{id} = $id if defined $id;
        $self->{source} = $source;
    } elsif (defined $args->{object}) {
        $self->{object} = $args->{object};
        $self->{class} = ref $self->{object}; # class = result_source
        ($self->{source}) = $self->{class} =~ /(\w+)$/;
        $self->{class_name} //= $self->{source};
        $self->{rs} = $self->{client}{schema}->resultset($self->{source});
    } elsif ($args->{source}) {
        $self->{source} = $args->{source};
    }
    unless ($self->{class}) {
        confess "Undefined tablename/source when creating new SmartSea::Object!" unless $self->{source};
        $self->{source} = table2source($self->{source});
        $self->{class} = 'SmartSea::Schema::Result::'.$self->{source};
        eval {
            $self->{rs} = $self->{client}{schema}->resultset($self->{source});
            if ($args->{search}) { # needed for getting a link object in some cases
                if ($self->{client}{debug}) {
                    for my $key (sort keys %{$args->{search}}) {
                        say STDERR "search term $key => $args->{search}{$key}";
                    }
                }
                $self->{object} = $self->{rs}->single($args->{search});
            } elsif (defined $args->{id}) {

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
                    @pk = ($args->{id}, $client->{cookie});
                } else {
                    die "$self->{class}: more than two primary keys!";
                }
                $self->{object} = $self->{rs}->can('my_find') ? 
                    $self->{rs}->my_find(@pk) : $self->{rs}->find(@pk);

                # is this in fact a subclass object?
                if ($self->{object} && $self->{object}->can('subclass')) {
                    my $source = $self->{object}->subclass;
                    if ($source) {
                        my $object = $self->{client}{schema}->resultset($source)->single({super => $args->{id}});
                        if ($object) {
                            # ok
                            $self->{source} = $source;
                            $self->{class} = 'SmartSea::Schema::Result::'.$self->{source};
                            $self->{rs} = $self->{client}{schema}->resultset($source);
                            $self->{object} = $object;
                        } else {
                            say STDERR "Error in db, missing subclass object for $self->{source}:$args->{id}";
                        }
                    }
                }
            }
        };
    }
    if (defined $args->{edit}) {
        $self->{edit} = $args->{edit};
    } elsif ($client->{admin}) {
        $self->{edit} = 1;
    } elsif ($client->{user} ne 'guest') {
        if ($self->{class}->can('owner')) {
            if ($self->{object}) {
                $self->{edit} = $client->{user} eq $self->{object}->owner;
            } else {
                $self->{edit} = 1;
            }
        }
    } else {
        $self->{edit} = 0;
    }
    $self->{class_name} //= $self->{source};
    $self->{id} = $self->{object} ? $self->{object}->id : '';
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

# classes can be related in many ways:
# class <- link -> related # related can be a part of class or independent
# class <- related # related can be a part of class or independent
# class -> object <- related # object can be a part of class or independent
# relationship_hash's 
#     keys are object methods that return an array of related objects
#     values are hashes with keys
# Keys are
#     source: the source of the related
#     link_source: for many to many: the link source
#     ref_to_me: the column referring to the class (in link or related)
#     set_to_null: ignored column
#     ref_to_related: the column referring to the related in the link class
#     class_column: required column in related
#     class_widget: subroutine which returns a widget for the class_column
sub relationship_hash {
    my ($self) = @_;
    return $self->{class}->relationship_hash if $self->{class}->can('relationship_hash');
    return {};
}

sub relationship {
    my ($self, $related) = @_;
    my $relationships = $self->relationship_hash;
    for my $attr (keys %$relationships) {
        my $relationship = $relationships->{$attr};
        if ($related->{source} eq $relationship->{source}) {
            if ($self->{source} eq $related->{source}) {
                # need to check which one of the self references this is
                if ($relationship->{ref_to_related}) {
                    # not yet existing case
                    die "$self->{source} eq $related->{source} and ref_to_related";
                } elsif ($related->{object} && $related->{object}->$relationship->{ref_to_me} == $self->{id}) {
                    return $relationship;
                } elsif ($self->{client}{parameters}{$relationship->{ref_to_me}}) {
                    return $relationship;
                }
            } else {
                return $relationship;
            }
        }
    }
    my $superclass = $related->superclass;
    return $self->relationship({source => $superclass}) if $superclass;
    return undef;
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
    return SmartSea::Object->new({ object => $super }, $self->{client}) if $class;
}

sub subclass {
    my ($self) = @_;
    croak "Must have result object to call subclass." unless $self->{object};
    return $self->{object}->subclass if $self->{object}->can('subclass');
}

sub need_form_for_child {
    my ($self, $child) = @_;
    return $self->{class}->need_form_for_child($child->{source}) if $self->{class}->can('need_form_for_child');
    return 1;
}

sub columns2 {
    my ($self, $parent, $columns) = @_;
    $columns = {} unless defined $columns;
    my @columns;
    my $columns_info;
    if ($self->{class}->can('my_columns_info')) {
        $columns_info = $self->{object} ? 
            $self->{object}->my_columns_info($parent) : 
            $self->{class}->my_columns_info($parent);
        @columns = keys %$columns_info;
    } else {
        @columns = $self->{class}->columns;
    }
    for my $column (@columns) {
        my $meta = $columns_info ? $columns_info->{$column} : $self->{class}->column_info($column);
        delete $meta->{value};
        if ($meta->{is_superclass} || $meta->{is_part}) {
            my $obj = SmartSea::Object->new({source => $meta->{source}}, $self->{client});
            $meta->{columns} = {};
            $obj->columns2(undef, $meta->{columns});
        }
        $columns->{$column} = $meta;
    }
    return $columns;
}

sub values_from_parameters {
    my ($self, $columns) = @_;
    my $parameters = $self->{client}{parameters};
    my @errors;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        if ($meta->{columns}) {
            if ($meta->{not_null} || $parameters->{$column.'_is'}) {
                $meta->{has_value} = 1;
                # TODO: child parameters should be prefixed with child name
                my $part = SmartSea::Object->new({source => $meta->{source}}, $self->{client});
                my @errors2 = $part->values_from_parameters($meta->{columns});
                push @errors, @errors2 if @errors2;
            }
        } elsif ($column eq 'id') {
            $meta->{value} = $parameters->{$column} // $self->next_id;
        } elsif ($column eq 'owner') {
            $meta->{value} = $self->{client}{user}; # admin can set user?
        } elsif ($column eq 'cookie') {
            $meta->{value} = $self->{client}{cookie};
        } else {
            next unless exists $parameters->{$column};
            $meta->{value} = $parameters->{$column};
            unless (defined($meta->{value})) {
                $meta->{value} = $meta->{default} if exists $meta->{default};
            }
            if ($meta->{value} eq '') {
                $meta->{value} = $meta->{default} if $meta->{empty_is_default};
                $meta->{value} = undef if $meta->{empty_is_null};
            }
            push @errors, "$column is required for $self->{source}" if !defined($meta->{value}) && $meta->{not_null};
            next unless $meta->{is_foreign_key};
            my $related = SmartSea::Object->new({source => $meta->{source}, id => $parameters->{$column}}, $self->{client});
            if (defined $related->{object}) {
                $meta->{value} = $related->{object};
            } else {
                push @errors, "$meta->{source}:$parameters->{$column} does not exist" ;
            }
        }
    }
    return @errors;
}

sub values_from_relationship {
    my ($self, $columns, $parent, $relationship) = @_;
    my @errors;
    my $class_column = $relationship->{class_column};
    if ($class_column) {
        my $class = $self->{client}{parameters}{$class_column};
        if ($class) {
            if ($relationship->{link_source}) {
                my $ref = $relationship->{ref_to_related};
                $columns->{$ref}{value} = $class if $columns->{$ref};
            } else {
                $columns->{$class_column}{value} = $class if $columns->{$class_column};
            }
        } else {
            push @errors, "$class_column is required for defining relationship from $parent->{source} to $self->{source}"
                unless $relationship->{link_source};
        }
    }
    if ($parent->{id}) {
        my $ref = $relationship->{ref_to_me};
        $columns->{$ref}{value} = $parent->{id} if $columns->{$ref};
        $columns->{$relationship->{set_to_null}}{value} = 'NULL' if $relationship->{set_to_null};
    } else {
        push @errors, "parent id is required to defined relationship from $parent->{source} to $self->{source}";
    }
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        next unless $meta->{is_superclass};
        my $super = SmartSea::Object->new({source => $meta->{source}}, $self->{client});
        $super->values_from_relationship($meta->{columns}, $parent, $relationship);
    }
    return @errors;
}

sub values_from_self {
    my ($self, $columns) = @_;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        $meta->{value} = $self->{object}->$column;
        if ($meta->{columns}) {
            if ($meta->{value}) {
                my $part = SmartSea::Object->new({object => $meta->{value}}, $self->{client});
                $part->values_from_self($meta->{columns});
            }
        }
    }
}

sub jsonify {
    my ($columns) = @_;
    my %json;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        $json{$column} = {};
        my $json = $json{$column};
        for my $key (keys %$meta) {
            if ($key eq 'columns') {
                $json->{columns} = jsonify($meta->{columns});
            } else {
                next if $key =~ /^_/ || ref $meta->{$key} eq 'CODE';
                if (ref $meta->{$key}) {
                    $json->{$key} = $meta->{$key}->id;
                } else {
                    $json->{$key} = $meta->{$key};
                }
            }
        }
    }
    return \%json;
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

sub tree {
    my ($self, $oids) = @_;
    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self->{client}) : undef;
    my $columns = $self->columns2($parent);
    $self->values_from_self($columns) if $self->{object};
    
    if (exists $self->{object}) {
        $columns = jsonify($columns);
        $columns->{related} = [];
        if ($self->{class}->can('relationship_hash')) {
            for my $key (keys %{$self->{class}->relationship_hash}) {
                push @{$columns->{related}}, $key;
            }
        }
        return $columns;
        if ($self->{object}->can('tree')) {
            return $self->{object}->tree($self->{client}{parameters}) ;
        } else {
            return {id => $self->{object}->id};
        }
    } else {
        my @rows;
        my $search = {};
        my $parameters = $self->{client}{parameters};
        for my $column (keys %$parameters) {
            # fixme: only top level attrs now
            next unless $columns->{$column};
            $search->{$column} = { '!=', undef } if $parameters->{$column} eq 'notnull';
        }
        #my $tree = $self->{class}->can('tree');
        for my $row ($self->{rs}->search($search, {order_by => {-asc => 'id'}})) {
            my %json = (id => $row->id);
            $json{name} = $row->name if $row->can('name');
            #push @rows, $tree ? $row->tree : {};
            push @rows, \%json;
        }
        return \@rows;
        
        if ($self->{rs}->can('tree')) {
            return $self->{rs}->tree($self->{client}{parameters});
        } else {
            
        }
    }
}

sub update_or_create {
    my ($self, $oids) = @_;
    if ($self->{object}) {
        $self->update($oids);
    } else {
        $self->create($oids);
    }
}

# attempt to create an object or a link between objects, 
# if cannot, return false, which will lead to form if HTML
# does the input data (parent, parameters) completely define the related object?
sub create {
    my ($self, $oids, $columns) = @_;
    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self->{client}) : undef;

    if ($parent) {
        say STDERR "create $parent->{source}:$parent->{id} -> $self->{source}" if $self->{client}{debug};
        my $relationship = $parent->relationship($self);
        croak "Theres is no relationship between $parent->{source} and $self->{source} (or not enough information in input)"
            unless $relationship;
              
        if ($relationship->{link_source}) { # create a link object
            $self = SmartSea::Object->new({source => $relationship->{link_source}}, $self->{client});
            
            my $columns = $self->columns2($parent);
            my @errors = $self->values_from_parameters($columns);
            @errors = $self->values_from_relationship($columns, $parent, $relationship) unless @errors;
            return @errors if @errors;
                                   
            $self->create(undef, $columns);
            return;

        } elsif ($self->{object}) { # create a link
            $self->{object}->update({$relationship->{ref_to_me} => $parent->{id}});
            return;

        } else { # create an object

            my $columns = $self->columns2($parent);
            my @errors = $self->values_from_parameters($columns);
            @errors = $self->values_from_relationship($columns, $parent, $relationship) unless @errors;
            return @errors if @errors;

            $self->create(undef, $columns);
            return;
        }
    }
    say STDERR "create $self->{source}" if $self->{client}{debug};

    unless ($columns) {
        $columns = $self->columns2;
        my @errors = $self->values_from_parameters($columns);
        return @errors if @errors;
    }
        
    if ($self->{class}->can('is_ok')) {
        my $error = $self->{class}->is_ok($columns);
        croak $error if $error;
    }

    # create objects that are a part of this or the superclass object
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        next unless $meta->{columns};
        next unless $meta->{is_part} || $meta->{is_superclass};
        next unless $meta->{not_null} || $meta->{has_value};

        my $part = SmartSea::Object->new({source => $meta->{source}}, $self->{client});
        my @errors = $part->create(undef, $meta->{columns});
        return @errors if @errors;
        $columns->{$column}{value} = $part->{id};
        say STDERR "created $meta->{source}:$part->{id}" if $self->{client}{debug};
    }

    
    if ($self->{client}{debug} > 1) {
        for my $column (keys %$columns) {
            my $meta = $columns->{$column};
            say STDERR "  $column => ",($meta->{value}//'undef');
        }
    }
    my %value;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        next if $column eq 'id' && $self->{client}{sequences};
        $value{$column} = $meta->{value} if exists $meta->{value};
    }   
    $self->{object} = $self->{rs}->create(\%value);
    $self->{id} = $self->{object}->id;
    $self->{id} = $self->{id}->id if ref $self->{id};
    say STDERR "Created $self->{source}, id is ",$self->{id} if $self->{client}{debug};

    # make subclass object -- this is hack, should know what to create in the first place
    my $class = $self->subclass;
    if ($class) {
        say STDERR "Create $class subclass object with id $self->{id}" if $self->{client}{debug};
        my $obj = SmartSea::Object->new({source => $class}, $self->{client});
        $columns = $obj->columns2;
        my @errors = $obj->values_from_parameters($columns);
        croak @errors if @errors;
        # assuming no new parts
        my %value;
        for my $column (keys %$columns) {
            if ($column eq 'super') {
                $value{$column} = $self->{id};
            } else {
                my $meta = $columns->{$column};
                $value{$column} = ref $meta->{value} ? $meta->{value}->id : $meta->{value};
            }
        }   
        $obj->{object} = $obj->{rs}->create(\%value);
    }
    return ();
}

sub update {
    my ($self, $oids) = @_;

    say STDERR "update $self->{source} ",$self->{object}->id if $self->{client}{debug};
    
    my $columns = $self->columns;
    my $col_data = {};

    # create, update or delete embedded child objects
    my %delete;
    for my $col (keys %$columns) {
        next unless $columns->{$col}{is_part};
        if ($columns->{$col}{not_null}) {
            my $child = $self->{object}->$col;
            $child = SmartSea::Object->new({object => $child}, $self->{client});
            $child->update($oids);
        } elsif ($self->{client}{parameters}{$col.'_is'}) {
            # TODO: child parameters should be prefixed with child name
            my $child = $self->{object}->$col;
            unless ($child) {
                $child = SmartSea::Object->new({source => $columns->{$col}{source}}, $self->{client});
                $child->create($oids);
                $col_data->{$col} = $child->{object}->id;
            } else {
                $child = SmartSea::Object->new({object => $child}, $self->{client});
                $child->update($oids);
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
        next if $columns->{$col}{is_part};
        next unless exists $self->{client}{parameters}{$col};
        # todo: $parameters->{$col} may be undef?
        next if $self->{client}{parameters}{$col} eq '' && $columns->{$col}{empty_is_default};
        $col_data->{$col} = $self->{client}{parameters}{$col} if exists $self->{client}{parameters}{$col};
        $col_data->{$col} = undef if $columns->{$col}{empty_is_null} && $col_data->{$col} eq '';
    }

    if ($self->{class}->can('is_ok')) {
        my $error = $self->{class}->is_ok($col_data);
        croak $error if $error;
    }

    if ($self->{client}{debug} > 1) {
        for my $col (sort keys %$col_data) {
            say STDERR "  $col => ",($col_data->{$col}//'undef');
        }
    }
    $self->{object}->update($col_data);

    # delete children:
    for my $class_of_child (keys %delete) {
        $delete{$class_of_child}->delete;
    }

    # update superclass:
    my $super = $self->super;
    $super->update($oids) if $super;
    
}

# remove the link between this object and previous in path or delete this object
sub delete {
    my ($self, $oids) = @_;

    # is it actually a link that needs to be deleted?
    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self->{client}) : undef;
    if ($parent) {
        say STDERR "remove link $parent->{source}:$parent->{id}->$self->{source}:$self->{id}" if $self->{client}{debug};
        # we need the object which links parent to self
        my $relationship = $parent->relationship($self);
        if ($relationship) {
            if ($parent->{source} eq $self->{source}) {
                
                $self->{object}->update({$relationship->{ref_to_me} => undef});
                
            } elsif ($relationship->{link_source}) {

                my $args = {
                    source => $relationship->{link_source}, 
                    search => {
                        $relationship->{ref_to_me} => $parent->{id}, 
                        $relationship->{ref_to_related} => $self->{id}}
                };
                my $link = SmartSea::Object->new($args, $self->{client});
                croak "There is no relationship between $parent->{source}:$parent->{id} and $self->{source}:$self->{id}."
                    unless $link->{object};
                $link->{object}->delete;
                
            } else {
                
                $self->{object}->delete;
                
            }
        } else {
            croak "There is no relationship between $parent->{source} and $self->{source}.";
        }
        return;
    }

    say STDERR "delete $self->{source}:$self->{id}" if $self->{client}{debug};
    
    unless ($self->{object}) {
        my $error = "Could not find the requested $self->{source}.";
        say STDERR "Error: $error";
        return $error;
    }
    
    my $columns = $self->columns;
    my %delete;
    for my $col (keys %$columns) {
        if ($columns->{$col}{is_foreign_key} && $columns->{$col}{is_part}) {
            my $child = $self->{object}->$col;
            next unless $child;
            $delete{$columns->{$col}{source}} = $child->id;
        }
    }
    eval {
        say STDERR "delete $self->{object}" if $self->{client}{debug} > 1;
        $self->{object}->delete;
    };
    say STDERR "Error: $@" if $@;
    return "$@" if $@;

    # delete children:
    for my $source (keys %delete) {
        my $child = SmartSea::Object->new({source => $source, id => $delete{$source}}, $self->{client});
        $child->delete;
    }

    # delete superclass:
    my $super = $self->super;
    $super->delete($oids) if $super;
}

sub all {
    my ($self) = @_;
    say STDERR "all for $self->{source}" if $self->{client}{debug};
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

sub introspection {
    my ($meta) = @_;
    return $meta->{source} if $meta->{source};
    return '';
}

sub simple_items {
    my ($self, $columns) = @_;
    my @li;
    for my $column ($self->{class}->columns) {
        my $meta = $columns->{$column};
        my $value = exists $meta->{value} ? $meta->{value} : introspection($meta);
        if ($meta->{columns}) {
            my $part = ref $value ? 
                SmartSea::Object->new({object => $value}, $self->{client}) :
                SmartSea::Object->new({source => $meta->{source}}, $self->{client});
            my $li = $part->simple_items($meta->{columns});
            push @li, [li => [[b => [1 => $meta->{source}]], [ul => $li]]];
        } else {
            $value //= '(undef)';
            if (ref $value) {
                for my $b (qw/name id data/) {
                    if ($value->can($b)) {
                        $value = $value->$b;
                        last;
                    }
                }
            }
            push @li, [li => "$column: ",encode_entities_numeric($value)];
        }
    }
    return \@li;
}

# return object as an item for HTML lists
sub item {
    my ($self, $oids, $children, $opt) = @_;
    $opt //= {};
    $opt->{url} //= '';
    $self->{edit} = 0 if $opt->{stop_edit};
    say STDERR "item for $self->{source}:$self->{id}, edit=$self->{edit}" if $self->{client}{debug};

    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self->{client}) : undef;
    
    return $self->item_class($oids, $parent, $self->all, $opt) unless exists $self->{object};

    my $source = $self->superclass // $self->{source};
    my $url = $opt->{url}.'/'.source2table($source);

    my @content = a(link => "Show all ".plural($self->{class_name}), url => $url);

    $url .= ':'.$self->{id} if $self->{object};
    # fixme: do not add edit if this made instead of a link object with nothing to edit
    push @content, [1 => ' '], a(link => 'edit this one', url => $url.'?request=edit') if $self->{edit};

    my $columns = $self->columns2($parent);
    $self->values_from_self($columns) if $self->{object};
  
    my $li = $self->simple_items($columns);

    if ($self->{object} && $self->{object}->can('info')) {
        my $info = $self->{object}->info($self->{client});
        push @$li, [li => $info] if $info;
    }
    
    push @$li, $self->related_items($oids, {url => $url}) if $self->{object};
    
    return [[b => @content], [ul => $li]];
}

# return item_class or items from objects of related class,
# objects are obtained by the relationship method
sub related_items {
    my ($self, $oids, $opt) = @_;
    say STDERR "related_items for $self->{source}:$self->{id}" if $self->{client}{debug};
    my $next = ($oids && $oids->has_next) ? $oids->next : undef;
    # items can be open or closed
    # open if there is $next whose source is what relationships tells
    # TODO: what if there are more than one children with the same source?
    my @items;
    my $relationships = $self->relationship_hash;
    for my $relationship_name (sort keys %$relationships) {
        my %relationship = %{$relationships->{$relationship_name}};
        if (defined $next) {
            my ($table, $id) = split /:/, $next;
            if (table2source($table) eq $relationship{source}) {
                $relationship{id} = $id;
            }
        }
        
        my $obj = SmartSea::Object->new(\%relationship, $self->{client});
        $obj->{edit} = 0 unless $self->{edit};
        my $objs = [$self->{object}->$relationship_name];
        next if @$objs == 0 && !$self->{edit};
        next if @$objs == 1 && !$objs->[0];
        my $obj_is_open = 0;
        if ($obj->{object}) {
            for my $has_obj (@$objs) {
                if ($has_obj->id == $obj->{object}->id) {
                    $obj_is_open = 1;
                    last;
                }
            }
        }
        say STDERR "obj is open? $obj_is_open" if $self->{client}{debug};
        my %opt = (url => $opt->{url}, stop_edit => $relationship{stop_edit} // $opt->{stop_edit});
        if ($obj_is_open) {
            push @items, [li => $obj->item($oids->with_index('next'), [], \%opt)];
        } else {
            delete $obj->{object};
            my $for_add = $relationship{class_widget}->($self, $objs) if $relationship{class_widget};
            $opt{for_add} = $for_add;
            $opt{button} = 'Add';
            my $parent = $self;
            $parent = undef if (defined $relationship{parent_is_parent} && $relationship{parent_is_parent} == 0);
            push @items, [li => $obj->item_class($oids, $parent, $objs, \%opt)];
        }
    }
    my $super = $self->super;
    push @items, $super->related_items($oids, $opt) if $super;
    return @items;
}

sub item_class {
    my ($self, $oids, $parent, $objects, $opt) = @_;
    say STDERR "item_class for $self->{source}" if $self->{client}{debug};
    my $url = $opt->{url}.'/'.source2table($self->{source});
        
    my @li;
    for my $obj (@$objects) {
        my @content = a(link => $obj->name, url => $url.':'.$obj->id);
        if ($self->{edit}) {
            push @content, [1 => ' '], a(link => 'edit', url => $url.':'.$obj->id.'?request=edit');
            my $source = $obj->result_source->source_name;
            my $name = '"'.$obj->name.'"';
            $name =~ s/'//g;
            $name = encode_entities_numeric($name);
            my $onclick = $parent ?
                "return confirm('Are you sure you want to remove the link to $source $name?')" :
                "return confirm('Are you sure you want to delete the $source $name?')";
            my $value = $parent ? 'Remove' : 'Delete';
            my %attr = (name => $obj->id, value => $value);
            $attr{onclick} = $onclick unless $self->{client}{no_js};
            push @content, [1 => ' '], button(%attr); # to do: remove or delete?
        }
        if ($self->{source} eq 'Dataset') {
            my %opt = (url => $opt->{url}, stop_edit => 1);
            my $p = SmartSea::Object->new({object => $obj, edit => 0}, $self->{client});
            my @p = $p->related_items($oids, \%opt);
            push @content, [ul => \@p] if @p;
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
            push @content, button(value => $opt->{button} // 'Add');
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
    my ($self, $oids) = @_;
    say STDERR "form for $self->{source}" if $self->{client}{debug};

    my $parent = ($oids && $oids->has_prev) ? SmartSea::Object->new({oid => $oids->prev}, $self->{client}) : undef;

    # TODO: child columns are now in parameters and may mix with parameters for self

    my $columns = $self->columns2($parent);
    my @widgets;
    my $title = $self->{object} ? 'Editing ' : 'Creating ';
    $title .= $self->{object} ? $self->{object}->name : $self->{source};
    push @widgets, [p => $title];

    # if the form is in the context of a parent
    if ($parent) {
        my $relationship = $parent->relationship($self);
        my @errors = $self->values_from_relationship($columns, $parent, $relationship);
        # if not ok, then either ref to me(parent) or class column, or possibly ref to related, could not be determined
        # don't care about that here, care only about what we could get
        push @widgets, $self->hidden_widgets($columns, $relationship);
    }

    # obtain default values for widgets
    # todo, what if there is no oids and this is a layer etc? bail out?
    $self->values_from_parameters($columns);
    
    if ($self->{object}) {

        $self->values_from_self($columns);

        # if the object has external sources for column values
        # example: dataset, if path is given, that can be examined
        if ($self->{object}->can('auto_fill_cols')) {
            $self->{object}->auto_fill_cols($self->{client});
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
            my $obj = SmartSea::Object->new({oid => $oids->at($id)}, $self->{client});
            for my $key (keys %$columns) {
                next if $key eq 'id';
                #next if defined $col_data->{$key};
                next unless $obj->{object}->result_source->has_column($key);
                say STDERR "getting $key from upstream" if $self->{client}{debug};
                $from_upstream{$key} = $obj->{object}->$key;
            }
        }
        my $has_upstream;
        for my $key (keys %$columns) {
            next if defined $self->{client}{parameters}{$key};
            next unless defined $from_upstream{$key};
            say STDERR "$key => $from_upstream{$key} is from upstream" if $self->{client}{debug};
            $has_upstream = 1;
            $self->{client}{parameters}->add($key => $from_upstream{$key});
        }
        push @widgets, [p => {style => 'color:darkgreen;font-style:italic'}, 
                        'Filled data is from parent objects and for information only. '.
                        'Please delete or overwrite them.'] 
                            if $has_upstream;
    }
    my $super = $self->super;
    push @widgets, [
        fieldset => [[legend => $super->{source}], $super->widgets($columns->{super}{columns})]
    ] if $super;
    push @widgets, $self->widgets($columns);
    push @widgets, button(value => 'Save'), [1 => ' '], button(value => 'Cancel');
    return [fieldset => [[legend => $self->{source}], @widgets]];
}

# 
sub hidden_widgets {
    my ($self, $columns, $relationship) = @_;
    my @widgets;
    for my $column (keys %$columns) {
        next if $column eq 'id';
        next if $column eq 'owner';
        my $meta = $columns->{$column};
        next unless defined $meta->{value};
        say STDERR "known data: $column => $meta->{value}" if $self->{client}{debug} > 1;
        
        if ($meta->{columns}) {
            my $part = SmartSea::Object->new({object => $meta->{value}}, $self->{client});
            push @widgets, $part->hidden_widgets($meta->{columns});
        } else {
            if (ref $meta->{value}) {
                if ($meta->{value} ne 'NULL') {
                    my $val = $self->{client}{schema}->
                        resultset($meta->{source})->
                        single({id => $meta->{value}->id})->name;
                    push @widgets, [p => [1 => "$column: $val"]];
                }
                push @widgets, hidden($column => $meta->{value}->id);
                $meta->{widget} = 1;
            }
        }
    }
    return @widgets;
}

sub widgets {
    my ($self, $columns) = @_;
    my @fcts;
    my @form;
    for my $column ($self->{class}->columns) {
        next if $column eq 'super';
        my $meta = $columns->{$column};
        next if $meta->{widget};
        say STDERR 
            "widget: $column => ",
            ($meta->{value}//'undef'),' ',
            ($meta->{is_part}//'reg') if $self->{client}{debug} > 1;
        my $input;
        for my $info_text (qw/data_type html_input/) {
            $meta->{$info_text} = '' unless $meta->{$info_text};
        }
        if ($meta->{data_type} eq 'text') {
            $input = text_input(
                name => $column,
                size => ($meta->{html_size} // 10),
                value => $meta->{value} // ''
            );
        } elsif ($meta->{data_type} eq 'textarea') {
            $input = textarea(
                name => $column,
                rows => $meta->{rows},
                cols => $meta->{cols},
                value => $meta->{value} // ''
            );
        } elsif ($meta->{is_foreign_key} && !$meta->{is_part}) {
            my $objs;
            if (ref $meta->{objs} eq 'ARRAY') {
                $objs = $meta->{objs};
            } elsif (ref $meta->{objs} eq 'CODE') {
                $objs = [];
                for my $obj ($self->{client}{schema}->resultset($meta->{source})->all) {
                    if ($meta->{objs}->($obj)) {
                        push @$objs, $obj;
                    }
                }
            } elsif ($meta->{objs}) {
                $objs = [$self->{client}{schema}->resultset($meta->{source})->search($meta->{objs})];
            } else {
                $objs = [$self->{client}{schema}->resultset($meta->{source})->all];
            }
            my $id;
            if (defined $meta->{value}) {
                if (ref $meta->{value}) {
                    $id = $meta->{value}->id;
                } else {
                    $id = $meta->{value};
                }
            }
            $input = drop_down(
                name => $column,
                objs => $objs,
                selected => $id,
                values => $meta->{values},
                allow_null => $meta->{allow_null}
            );
        } elsif ($meta->{html_input} eq 'checkbox') {
            $input = checkbox(
                name => $column,
                visual => $meta->{cue},
                checked => $meta->{value}
            );
        } elsif ($meta->{html_input} eq 'spinner') {
            $input = spinner(
                name => $column,
                min => $meta->{min},
                max => $meta->{max},
                value => $meta->{value} // 1
            );
        }
        if ($meta->{is_part}) {
            unless ($meta->{not_null}) {
                my $fct = $column.'_fct';
                my $cb = $column.'_cb';
                push @form, [ p => checkbox(
                                  name => $column.'_is',
                                  visual => "Define ".$meta->{source},
                                  checked => $meta->{value},
                                  id => $cb )
                ];
                my $code =<< "END_CODE";
function $fct() {
  var cb = document.getElementById("$cb");
  var id = "$column";
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
                push @form, hidden($column.'_is', 1);
            }
            my $part = SmartSea::Object->new({source => $meta->{source}, object => $meta->{value}}, $self->{client});
            say STDERR "part ",($part->{object}//'undef') if $self->{client}{debug};
            my @style = $part->widgets($meta->{columns});
            push @form, [fieldset => {id => $column}, [[legend => $part->{source}], @style]];
        } else {
            push @form, [ p => [[1 => "$column: "], $input] ] if $input;
        }
    }
    if (@fcts) {
        push @form, [script => {src=>"http://code.jquery.com/jquery-1.10.2.js"}, ''];
        push @form, [script => join("\n",@fcts)];
    }
    return @form;
}

1;
