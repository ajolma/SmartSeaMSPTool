package SmartSea::Object;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Scalar::Util qw(blessed weaken);
use HTML::Entities qw/encode_entities_numeric/;
use Encode qw(decode encode);
use JSON;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

use Data::Dumper;

binmode STDERR, ":utf8";

sub from_app {
    my ($class, $app) = @_;
    
    my $path = $app->{path};
    $path =~ s/^$app->{root}//;
    my @oids = split /\//, $path;
    shift @oids; # the first ''

    my @objects = ();
    my $object;
    for my $oid (@oids) {
        my ($tag, $id) = split /:/, $oid;
        my %args = (id => $id, app => $app);
        unless ($object) {
            # first in path, tag is table name
            croak "The first thing in the path must be a class name." unless $tag;
            $args{class} = $tag;
            $args{source} = $app->{sources}{$tag};
            croak "No such class: '$args{class}'." unless $args{source};
            $args{name} = $args{source};
            
        } else {
            # object is parent, tag is relationship name
            $args{relation} = $object->relationship_hash->{$tag};
            croak "No such relation: '$object->{class}.$tag'." unless $args{relation};
            $args{relation}{key} = 'id' unless $args{relation}{key};
            $args{relation}{related} = $tag;
            $args{source} = $args{relation}{source};
            $args{class} = source2class($args{source});
            $args{name} = $args{relation}{name} // $args{source};
            $args{stop_edit} = $args{relation}{stop_edit};

        }
        
        $object = SmartSea::Object->new(\%args);
        push @objects, $object;
    }
    if (@objects > 1) {
        my $prev;
        for my $obj (@objects) {
            $obj->{prev} = $prev;
            $prev->{next} = $obj if $prev;
            weaken($obj->{prev});
            weaken($prev->{next});
            $prev = $obj;
        }
    }

    return @objects;
}

# in args give object, or source and possibly id or search
# polymorphic: returns the subclass object if this is one
sub new {
    my ($class, $args) = @_;
    confess "no app for object" unless $args->{app};
    my $self = {
        name => $args->{name}, # visual name
        class => $args->{class}, # class name for clients, table name in singular
        relation => $args->{relation}, # hash of relation to parent
        stop_edit => $args->{stop_edit}, # user is not allowed to change this or this' children
        app => $args->{app}
    };
    if (defined $args->{object}) {
        $self->{object} = $args->{object};
        $self->{result} = ref $self->{object}; # result_source
        ($self->{source}) = $self->{result} =~ /(\w+)$/; # the last part of the Perl class
        $self->{class} //= source2class($self->{source});
        $self->{name} //= $self->{source};
        $self->{rs} = $self->{app}{schema}->resultset($self->{source});
        $self->{id} = $self->{object}->id;
    } elsif ($args->{source}) {
        $self->{source} = $args->{source};
        $self->{class} //= source2class($self->{source});
        $self->{name} //= $self->{source};
        $self->{result} = 'SmartSea::Schema::Result::'.$self->{source};
        $self->{rs} = $self->{app}{schema}->resultset($self->{source});
        if ($args->{search}) { # needed for getting a link object in some cases
            if ($self->{app}{debug}) {
                for my $key (sort keys %{$args->{search}}) {
                    say STDERR "search term $key => $args->{search}{$key}";
                }
            }
            $self->{object} = $self->{rs}->single($args->{search});
            $self->{id} = $self->{object}->id;    
        } elsif (defined $args->{id}) {
            id($self, $args->{id});
        }
    } else {
        confess "SmartSea::Object->new requires either object or source";
    }
    if (defined $args->{edit}) {
        $self->{edit} = $args->{edit};
    } elsif ($self->{app}{admin}) {
        $self->{edit} = 1;
    } elsif ($self->{app}{user} ne 'guest') {
        if ($self->{result}->can('owner')) {
            if ($self->{object}) {
                $self->{edit} = $self->{app}{user} eq $self->{object}->owner;
            } else {
                $self->{edit} = 1;
            }
        }
    } else {
        $self->{edit} = 0;
    }
    bless $self, $class;
}

sub id {
    my ($self, $id) = @_;
    if ($id) {
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
        my @pk = $self->{result}->primary_columns;
        if (@pk == 1) {
            @pk = ($id);
        } elsif (@pk == 2) {
            # special case for rules, which have pk = id,cookie
            # 'find' of ResultSet for Rule is also replaced by 'my_find' to return default by default
            @pk = ($id, $self->{app}{cookie});
        } else {
            die "$self->{result}: more than two primary keys!";
        }
        $self->{object} = $self->{rs}->can('my_find') ? 
            $self->{rs}->my_find(@pk) : $self->{rs}->find(@pk);
        
        # is this in fact a subclass object?
        if ($self->{object} && $self->{object}->can('subclass')) {
            my $source = $self->{object}->subclass;
            if ($source) {
                my $object = $self->{app}{schema}->resultset($source)->single({super => $id});
                if ($object) {
                    # ok
                    $self->{source} = $source;
                    $self->{name} = $source;
                    $self->{result} = 'SmartSea::Schema::Result::'.$self->{source};
                    $self->{rs} = $self->{app}{schema}->resultset($source);
                    $self->{object} = $object;
                } else {
                    say STDERR "Error in db, missing subclass object for $self->{source}:$id";
                }
            }
        }
        $self->{id} = $self->{object}->id if $self->{object};
    } else {
        $self->{object} = undef;
    }
    return $self->{id};
}

sub first {
    my $self = shift;
    while (my $obj = $self->{prev}) {
        $self = $obj;
    }
    return $self;
}

sub last {
    my $self = shift;
    while (my $obj = $self->{next}) {
        $self = $obj;
    }
    return $self;
}

sub next {
    my $self = shift;
    return $self->{next};
}

sub prev {
    my $self = shift;
    return $self->{prev};
}

sub str {
    my $self = shift;
    return $self->{source} unless $self->{object};
    return "$self->{source}:$self->{id}";
}

sub str_all {
    my $self = shift;
    my $str = $self->str;
    while (my $obj = $self->{next}) {
        $str .= ','.$obj->str;
        $self = $obj;
    }
    return $str;
}

sub is {
    my ($self, $source) = @_;
    return 1 if $self->{source} eq $source;
    return unless $self->{result}->has_column('super');
    my $info = $self->{result}->column_info('super');
    return 1 if $info->{source} eq $source;
    return;
}

sub superclass {
    my ($self) = @_;
    return unless $self->{result}->has_column('super');
    my $info = $self->{result}->column_info('super');
    return source2class($info->{source});
}

sub super {
    my $self = shift;
    #return unless $self->{object};
    return unless $self->{result}->has_column('super');
    my $info = $self->{result}->column_info('super');
    my $super = $self->{object} ? $self->{object}->super : undef;
    #return unless $super;
    return SmartSea::Object->new({
        object => $super,
        #name => $self->{name},
        source => $info->{source},
        relation => $self->{relation},
        stop_edit => $self->{stop_edit},
        app => $self->{app}});
}

sub subclass {
    my ($self, $columns) = @_;
    my $can = $self->{result}->can('subclass');
    if ($self->{object}) {
        return $self->{object}->subclass if $can;
    } elsif ($columns) {
        return $self->{result}->subclass($columns) if $can;
    } else {
        croak "Must have result object or column data to call subclass." unless $self->{object};
    }
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
# parent <- link -> related # related can be a part of parent or independent
# parent <- related # related can be a part of parent or independent
# parent -> object <- related # object can be a part of class or independent
# relationship_hash's 
#     keys are object methods that return an array of related objects
#     values are hashes with keys
# Keys are
#     source: the source of the related
#     link_source: for many to many: the link source
#     ref_to_parent: the column referring to the parent (in link or related)
#     key: if id is not where ref_to_parent points
#     set_to_null: ignored column
#     ref_to_related: the column referring to the related in the link
#     class_column: required column in related
#     class_widget: subroutine which returns a widget for the class_column

sub relationship_hash {
    my ($self) = @_;
    return $self->{result}->relationship_hash if $self->{result}->can('relationship_hash');
    return {};
}

sub columns {
    my ($self, $columns) = @_;
    $columns = {} unless defined $columns;
    my $prev = $self->{prev} ? $self->{prev}{object} : undef;
    my $row = $self->{object} ? $self->{object} : $self->{result};
    my $columns_info = $row->columns_info(undef, $prev);
    for my $column (keys %$columns_info) {
        my $meta = $columns_info->{$column};
        delete $meta->{value};
        if ($meta->{is_superclass} || $meta->{is_part}) {
            my %args = (app => $self->{app});
            if ($self->{object}) {
                $args{object} = $self->{object}->$column;
            }
            $args{source} = $meta->{source} unless $args{object};
            my $obj = SmartSea::Object->new(\%args);
            $meta->{columns} = {};
            $obj->columns($meta->{columns});
        }
        $columns->{$column} = $meta;
    }
    return $columns;
}

sub set_to_columns {
    my ($columns, $col, $key, $value) = @_;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        if ($column eq $col) {
            $meta->{$key} = $value;
            last;
        }
        if ($meta->{columns}) {
            set_to_columns($meta->{columns}, $col, $key, $value);
        }
    }
}

sub values_from_parameters {
    my ($self, $columns, $fixed) = @_;
    my $parameters = $self->{app}{parameters};
    my @errors;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        my $key = $fixed ? 'fixed' : 'value';
        next if exists $meta->{value};
        if ($meta->{columns}) {
            if ($meta->{not_null} || $parameters->{$column.'_is'}) {
                $meta->{has_value} = 1;
                # TODO: child parameters should be prefixed with child name
                my $part = SmartSea::Object->new({source => $meta->{source}, app => $self->{app}});
                my @errors2 = $part->values_from_parameters($meta->{columns});
                push @errors, @errors2 if @errors2;
            }
        } elsif ($column eq 'id') {
            $meta->{value} = $parameters->{$column} // $self->next_id;
        } elsif ($column eq 'owner') {
            $meta->{value} = $self->{app}{user}; # admin can set user?
        } elsif ($column eq 'cookie') {
            if ($self->{app}{request} && $self->{app}{request} eq 'modify') {
                $meta->{value} = $self->{app}{cookie};
            }
        } else {
            # The goal is to get values from parameters and report errors
            # empty parameter string is interpreted as NULL
            # column meta values observed:
            # not_null: the column is NOT NULL in DB
            # has_default: the column has DEFAULT in DB
            # is_foreign_key: the column points to a related object
            my $required = $meta->{not_null} && !$meta->{has_default};
            unless (exists $parameters->{$column}) {
                push @errors, "$column is required for $self->{source}" if $required;
                next;
            }
            $meta->{$key} = $parameters->{$column};
            if (!defined($meta->{$key}) || $meta->{$key} eq '') { # considered default
                if ($required) {
                    push @errors, "$column is required for $self->{source}";
                    next;
                } elsif ($meta->{has_default}) {
                    delete $meta->{$key};
                } else {
                    $meta->{$key} = undef;
                }
            }
            next unless $meta->{is_foreign_key};
            my $related = SmartSea::Object->new({source => $meta->{source}, id => $meta->{$key}, app => $self->{app}});
            if (defined $related->{object}) {
                $meta->{$key} = $related->{object};
            } else {
                push @errors, "$meta->{source}:$meta->{$key} does not exist" if $required;
            }
        }
    }
    return @errors;
}

sub values_from_self {
    my ($self, $columns) = @_;
    confess "no obj" unless $self->{object};
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        $meta->{value} = $self->{object}->$column;
        if ($meta->{columns}) {
            if ($meta->{value}) {
                my $part = SmartSea::Object->new({object => $meta->{value}, app => $self->{app}});
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
                next if 
                    $key eq 'objs' || 
                    $key eq 'values' ||
                    $key =~ /^_/ || 
                    ref $meta->{$key} eq 'CODE';
                if (blessed $meta->{$key}) {
                    $json->{$key} = $meta->{$key}->id;
                } else {
                    $json->{$key} = $meta->{$key};
                }
            }
        }
    }
    return \%json;
}

sub read {
    my ($self) = @_;

    my $url = $self->{app}{url}.$self->{app}{root}.'/'.$self->{class};
    $url .= ':'.$self->{id} if $self->{object};
    while (my $next = $self->next) {
        $self = $next;
        $url .= '/'.$self->{relation}{related};
        $url .= ':'.$self->{id} if $self->{object};
    }
    if (exists $self->{object}) {
        my $columns = $self->columns;
        $self->values_from_self($columns) if $self->{object};
        $columns = jsonify($columns);
        $url .= '/';
        if ($self->{result}->can('relationship_hash')) {
            $columns->{related} = {};
            my $hash = $self->{result}->relationship_hash;
            for my $related (keys %$hash) {
                $columns->{related}{$related}{edit} = $hash->{$related}{no_edit} ? JSON::false : JSON::true;
                $columns->{related}{$related}{stop_edit} = $hash->{$related}{stop_edit};
                $columns->{related}{$related}{class} = source2class($hash->{$related}{source});
                $columns->{related}{$related}{href} = $url.$related.'?accept=json';
            }
        }
        $columns->{class} = $self->{class};
        return $columns;
        
    } else {
        my $columns = $self->columns;
        my @rows;
        my $search = {};
        my $parameters = $self->{app}{parameters};
        for my $column (keys %$parameters) {
            # fixme: only top level attrs now
            next unless $columns->{$column};
            $search->{$column} = { '!=', undef } if $parameters->{$column} eq 'notnull';
        }

        $url .= ':';
        if ($self->{prev} && $self->{prev}{object}) {
            my $method = $self->{relation}{related};
            for my $row ($self->{prev}{object}->$method($search)) {
                #next unless $row->ecosystem_component->name =~ /Vege/;
                my %json = (class => $self->{class}, id => $row->id, href => $url.$row->id.'?accept=json');
                $json{name} = $row->name if $row->can('name');
                push @rows, \%json;
            }
        } else {
            for my $row ($self->{rs}->search($search, {order_by => 'id'})) {
                my %json = (class => $self->{class}, id => $row->id, href => $url.$row->id.'?accept=json');
                $json{name} = $row->name if $row->can('name');
                push @rows, \%json;
            }
        }
        return \@rows;
    }
}

# attempt to create an object or a link between objects, 
# if cannot, return false, which will lead to form if HTML
# does the input data (parent, parameters) completely define the related object?
sub create {
    my ($self, $columns) = @_;

    if ($self->{prev} && $self->{prev}{object} && !$columns) {
        my $relationship = $self->{relation};
        confess "no key" unless $relationship->{key};
        my $parent_id = $self->{prev}{object}->get_column($relationship->{key});
        
        if ($relationship->{stop_edit} && !$self->{id}) {
            # update link(s)
            # delete old
            my $method = $relationship->{related};
            my @links = $self->{prev}{object}->$method;
            if ($relationship->{link_source}) {
                for my $child (@links) {
                    my $args = {
                        source => $relationship->{link_source}, 
                        search => {
                            $relationship->{ref_to_parent} => $self->{prev}{id},
                            $relationship->{ref_to_related} => $child->id},
                        app => $self->{app}
                    };
                    my $link = SmartSea::Object->new($args);
                    $link->{object}->delete if $link && $link->{object};
                }
            } else {
                for my $child (@links) {
                    $child->update({$relationship->{ref_to_parent} => undef});
                }
            }
            # add new
            my @id = $self->{app}{parameters}->get_all($self->{class});
            if ($relationship->{link_source}) {
                for my $id (@id) {
                    my $link = SmartSea::Object->new({source => $relationship->{link_source}, app => $self->{app}});
                    my $columns = $link->columns;
                    set_to_columns($columns, $relationship->{ref_to_parent}, value => $parent_id);
                    set_to_columns($columns, $relationship->{ref_to_related}, value => $id);
                    my @errors = $link->values_from_parameters($columns);
                    return @errors if @errors;
                    $link->create($columns);
                }
            } else {
                for my $id (@id) {
                    my $args = {
                        source => $self->{source}, 
                        id => $id,
                        app => $self->{app}
                    };
                    my $child = SmartSea::Object->new($args);
                    $child->update({$relationship->{ref_to_parent} => $parent_id});
                }
            }
            return;
        }

        say STDERR "create ",$self->{prev}->str," -> ",$self->str if $self->{app}{debug};
        if ($self->{object}) { # create a link
            
            if ($relationship->{link_source}) { # create a link object
                my $link = SmartSea::Object->new({source => $relationship->{link_source}, app => $self->{app}});
                my $columns = $link->columns;
                set_to_columns($columns, $relationship->{ref_to_parent}, value => $parent_id);
                set_to_columns($columns, $relationship->{ref_to_related}, value => $self->{id});
                my @errors = $link->values_from_parameters($columns);
                return @errors if @errors;
                $link->create($columns);

            } else {
                $self->{object}->update({$relationship->{ref_to_parent} => $parent_id});
            }
            return;

        } else { # create an object

            my $columns = $self->columns;
            set_to_columns($columns, $relationship->{ref_to_parent}, value => $parent_id);
            my @errors = $self->values_from_parameters($columns);
            return @errors if @errors;
            $self->create($columns);
            return;
        }
    }
    say STDERR "create $self->{source}" if $self->{app}{debug};

    unless ($columns) {
        $columns = $self->columns;
        my @errors = $self->values_from_parameters($columns);
        return @errors if @errors;
    }
        
    # create objects that are a part of this or the superclass object
    # note that this method is called recursively
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        next unless $meta->{columns};
        next unless $meta->{is_part} || $meta->{is_superclass};
        next unless $meta->{not_null} || $meta->{has_value};

        my $part = SmartSea::Object->new({source => $meta->{source}, app => $self->{app}});
        my @errors = $part->create($meta->{columns});
        return @errors if @errors;
        $columns->{$column}{value} = $part->{id};
        say STDERR "created $meta->{source}:$part->{id}" if $self->{app}{debug};
    }

    # values for this object
    my %values;
    for my $column (keys %$columns) {
        my $meta = $columns->{$column};
        next if $column eq 'id' && $self->{app}{sequences};
        $values{$column} = $meta->{value} if exists $meta->{value};
        say STDERR "  $column => ",($values{$column}//'undef') if $self->{app}{debug} > 1;
    }
    if ($self->{result}->can('is_ok')) {
        my $error = $self->{result}->is_ok(\%values);
        croak $error if $error;
    }

    $self->{object} = $self->{rs}->create(\%values);
    $self->{id} = $self->{object}->id;
    $self->{id} = $self->{id}->id if ref $self->{id};
    say STDERR "created $self->{source}, id is ",$self->{id} if $self->{app}{debug};

    # make subclass object, try to delete super object if this fails
    if (my $class = $self->subclass) {
        say STDERR "Create $class subclass object with id $self->{id}" if $self->{app}{debug};
        my $object = SmartSea::Object->new({source => $class, app => $self->{app}});
        my $columns = $object->columns;
        my @errors = $object->values_from_parameters($columns);
        if (@errors) {
            $self->delete;
            croak join(', ',@errors);
        }
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
        $object->{object} = $object->{rs}->create(\%value);
        # replace self with object
        if ($self->{prev}) {
            $object->{prev} = $self->{prev};
            delete $self->{prev};
            weaken($object->{prev});
            $object->{prev}{next} = $object;
            weaken($object->{prev}{next});
        }
    }
    return ();
}

sub update {
    my $self = shift;

    confess "Update was requested for a non-existing $self->{source} object." unless $self->{object};

    say STDERR "update ",$self->str if $self->{app}{debug};
    
    my $columns = $self->columns;
    my $col_data = {};

    # create, update or delete embedded child objects
    my %delete;
    for my $col (keys %$columns) {
        my $meta = $columns->{$col};
        next unless $meta->{is_part};
        if ($meta->{not_null}) {
            my $child = $self->{object}->$col;
            $child = SmartSea::Object->new({object => $child, app => $self->{app}});
            $child->update;
        } elsif ($self->{app}{parameters}{$col.'_is'}) {
            # TODO: child parameters should be prefixed with child name
            my $child = $self->{object}->$col;
            unless ($child) {
                $child = SmartSea::Object->new({source => $meta->{source}, app => $self->{app}});
                $child->create;
                $col_data->{$col} = $child->{object}->id;
            } else {
                $child = SmartSea::Object->new({object => $child, app => $self->{app}});
                $child->update;
            }
        } else {
            $col_data->{$col} = undef;
            if (my $child = $self->{object}->$col) {
                $delete{$col} = $child; # todo: make child SmartSea::Object
            }
        }
    }

    my @errors;

    # collect update data from input
    for my $col (keys %$columns) {
        my $meta = $columns->{$col};
        next if $meta->{is_part};

        # lighter version of what's in values_from_parameters
        next unless exists $self->{app}{parameters}{$col};
        $col_data->{$col} = $self->{app}{parameters}{$col};
        if (!defined($col_data->{$col}) || $col_data->{$col} eq '') { # considered default
            $col_data->{$col} = undef; # should set to NULL or DEFAULT (check!)
        }
        next unless $meta->{is_foreign_key};
        if (defined $col_data->{$col}) {
            my $related = SmartSea::Object->new(
                {
                    source => $meta->{source}, 
                    id => $col_data->{$col}, 
                    app => $self->{app}
                });
            unless (defined $related->{object}) {
                push @errors, "$meta->{source}:$col_data->{$col} does not exist";
            }
        } else {
            # 
        }
    }

    if ($self->{object}->can('is_ok')) {
        my $error = $self->{object}->is_ok($col_data);
        push @errors, $error if $error;
    }

    if ($self->{app}{debug} > 1) {
        for my $col (sort keys %$col_data) {
            say STDERR "  update $col => ",($col_data->{$col}//'undef');
        }
    }
    croak join(', ', @errors) if @errors;
    
    #fixme: move create, update or delete embedded child objects here
    
    $self->{object}->update($col_data);

    # delete children:
    for my $class_of_child (keys %delete) {
        $delete{$class_of_child}->delete;
    }

    # update superclass:
    if (my $super = $self->super) {
        $super->update;
    }

    return;
}

# remove the link between this object and previous in path or delete this object
sub delete {
    my $self = shift;

    # is it actually a link that needs to be deleted?
    if ($self->{prev}) {
        say STDERR "remove link ",$self->{prev}->str," -> ",$self->str if $self->{app}{debug};
        my $relationship = $self->{relation};
        if ($relationship) {
            if ($self->{prev}{source} eq $self->{source}) {

                say STDERR "update self" if $self->{app}{debug};
                $self->{object}->update({$relationship->{ref_to_parent} => undef});
                return;
                
            } elsif ($relationship->{link_source}) {

                # we need the object which links parent to self
                say STDERR "delete link object" if $self->{app}{debug};
                my $args = {
                    source => $relationship->{link_source}, 
                    search => {
                        $relationship->{ref_to_parent} => $self->{prev}{id},
                        $relationship->{ref_to_related} => $self->{id}},
                    app => $self->{app}
                };
                my $link = SmartSea::Object->new($args);
                croak "There is no relationship between ",$self->{prev}->str," and ",$self->str,"."
                    unless $link->{object};
                $link->{object}->delete;
                return;
                
            }
        } else {
            croak "There is no relationship between ",$self->{prev}->str," and ",$self->str,".";
        }
        
    }

    say STDERR "delete ",$self->str if $self->{app}{debug};
    
    croak "A request to delete unexisting ".$self->{source}." object." unless $self->{object};
    
    my $columns = $self->columns;
    my %delete;
    for my $col (keys %$columns) {
        my $meta = $columns->{$col};
        if ($meta->{is_foreign_key} && $meta->{is_part}) {
            my $child = $self->{object}->$col;
            next unless $child;
            $delete{$meta->{source}} = $child->id;
        }
    }
    $self->{object}->delete;

    # delete children:
    for my $source (keys %delete) {
        my $child = SmartSea::Object->new({source => $source, id => $delete{$source}, app => $self->{app}});
        $child->delete;
    }

    # delete superclass:
    if (my $super = $self->super) {
        say STDERR "Delete super object $super." if $self->{app}{debug};
        $super->delete;
    }
    
    delete $self->{object};
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
    my $order_by = $self->{result}->can('order_by') ? $self->{result}->order_by : {-asc => $col};
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
    for my $column ($self->{result}->columns) {
        next unless exists $columns->{$column};
        my $meta = $columns->{$column};
        my $value = exists $meta->{value} ? $meta->{value} : introspection($meta);
        if ($meta->{columns}) {
            my $part = ref $value ? 
                SmartSea::Object->new({object => $value, app => $self->{app}}) :
                SmartSea::Object->new({source => $meta->{source}, app => $self->{app}});
            my $li = $part->simple_items($meta->{columns});
            push @li, [li => [[b => [1 => $meta->{source}]], [ul => $li]]];
        } else {
            $value //= '(undef)';
            if (ref $value) {
                for my $key (qw/name id data/) {
                    if ($value->can($key)) {
                        $value = $value->$key;
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
    my ($self, $children, $opt) = @_;
    $opt //= {};
    $opt->{url} //= '';
    $self->{edit} = 0 if $opt->{stop_edit};
    
    say STDERR "item for ",$self->str,", edit: $self->{edit}, url: $opt->{url}" if $self->{app}{debug};

    return $self->item_class($self->all, $opt) unless exists $self->{object};

    my $tag = $self->{relation} ? $self->{relation}{related} : ($self->superclass // $self->{class});
    my $url = $opt->{url}.'/'.$tag;

    confess "no class name " unless defined $self->{name};
    my $name = $self->{name};
    $name = $self->{relation}{name} if $self->{relation} && $self->{relation}{name};
    my @content = a(link => "Show all ".plural($name), url => $url);

    $url .= ':'.$self->{id} if $self->{object};
    # fixme: do not add edit if this made instead of a link object with nothing to edit
    push @content, [1 => ' '], a(link => 'edit this one', url => $url.'?request=edit') if $self->{edit};

    # fixme?
    my $columns = $self->columns; # this doesn't call columns for is_part objects with real object
    $self->values_from_self($columns) if $self->{object};
  
    my $li = $self->simple_items($columns); # so here all cols (also unused) are shown

    if ($self->{object} && $self->{object}->can('info')) {
        my $info = $self->{object}->info($self->{app});
        push @$li, [li => $info] if $info;
    }
    
    push @$li, $self->related_items({url => $url}) if $self->{object};
    
    return [[b => @content], [ul => $li]];
}

# return item_class or items from objects of related class,
# objects are obtained by the relationship method
sub related_items {
    my ($self, $opt) = @_;
    my $next = $self->next;
    say STDERR "related_items for $self->{source}:$self->{id} next=",($next ? $next->str : '')," url = $opt->{url}"
        if $self->{app}{debug};
    # items can be open or closed
    # open if there is $next whose source is what relationships tells
    # TODO: what if there are more than one children with the same source?
    my @items;
    my $relationships = $self->relationship_hash;
    for my $key (sort keys %$relationships) {
        my $relation = $relationships->{$key};
        $relation->{related} = $key;
        my $edit = defined $self->{edit} && $self->{edit} == 0 ? 0 : 1;
        my $objs = [$self->{object}->$key];
        next if @$objs == 0 && !$self->{edit};
        next if @$objs == 1 && !$objs->[0];
        my $obj_is_open = 0;
        if ($next) {
            my $id = $next->{id};
            if ($id && $next->is($relation->{source})) {
                for my $has_obj (@$objs) {
                    if ($has_obj->id == $id) {
                        $obj_is_open = 1;
                        last;
                    }
                }
            }
        }
        say STDERR "$key $relation->{source} obj is open? $obj_is_open" if $self->{app}{debug};
        my %opt = (url => $opt->{url}, stop_edit => $relation->{stop_edit});
        if ($obj_is_open) {
            push @items, [li => $next->item([], \%opt)];
        } else {
            $edit = 0 if $relation->{no_edit};
            my $next = SmartSea::Object->new({
                name => $relation->{name} // $relation->{source},
                relation => $relation,
                stop_edit => $relation->{stop_edit} // $self->{stop_edit},
                source => $relation->{source},
                edit => $edit, 
                app => $self->{app}});
            $opt{for_add} = $relation->{class_widget}->($self, $objs) if $relation->{class_widget};
            $opt{button} = 'Add';
            $next->{prev} = $self;
            $next->{prev} = undef if (defined $relation->{parent_is_parent} && $relation->{parent_is_parent} == 0);
            push @items, [li => $next->item_class($objs, \%opt)];
        }
    }
    my $super = $self->super;
    push @items, $super->related_items($opt) if $super;
    return @items;
}

sub item_class {
    my ($self, $objects, $opt) = @_;
    my $tag = $self->{relation} ? $self->{relation}{related} : $self->{class};
    say STDERR "item_class for $self->{source}, url = $opt->{url}, tag => $tag" if $self->{app}{debug};
    my $url = $opt->{url}.'/'. $tag;
        
    my @li;
    for my $obj (@$objects) {
        my @content = a(link => $obj->name, url => $url.':'.$obj->id);
        if ($self->{edit}) {
            push @content, [1 => ' '], a(link => 'edit', url => $url.':'.$obj->id.'?request=edit');
            my $action = $self->{prev} ? 'Remove' : 'Delete';
            my $label = $action;
            $label .= ' the link to' if $action eq 'Remove';
            my $src = $obj->result_source->source_name;
            my $str = 'Are you sure you want to '.lc($label).' '.$src." '".$obj->name."'?";
            my %attr = (
                content => $action,
                name => 'delete',
                value => $obj->id,
                onclick => ($self->{app}{js} ? "return confirm(".javascript_string($str).")" : undef),
                );
            push @content, [1 => ' '], button(%attr);
        }
        if ($self->{source} eq 'Dataset') {
            my %opt = (url => $url.':'.$obj->id, stop_edit => 1);
            my $p = SmartSea::Object->new({
                object => $obj,
                edit => 0, 
                app => $self->{app} });
            my @p = $p->related_items(\%opt);
            push @content, [ul => \@p] if @p;
        }
        push @li, [li => @content];
    }
    if ($self->{edit}) {
        my $add = 1;
        my $extra = 0;
        if ($opt && defined $opt->{for_add}) {
            if (ref $opt->{for_add}) {
                $extra = $opt->{for_add}
            } else {
                $add = 0 if $opt->{for_add} == 0;
            }
        }
        if ($add) {
            my @content;
            push @content, $extra, [0=>' '] if $extra;
            push @content, button(name => 'request', value => 'create', content => $opt->{button} // 'Add');
            push @li, [li => \@content] if @content;
        }
    }
    my $ul;
    if ($self->{edit}) {
        $ul = [form => {action => $url, method => 'POST'}, [ul => \@li]];
    } else {
        $ul = [ul => \@li];
    }
    confess "no class name " unless defined $self->{name};
    return [[b => plural($self->{name})], $ul];
}

sub form {
    my ($self, $args) = @_;
    say STDERR "form for $self->{source}" if $self->{app}{debug};

    # TODO: child columns are now in parameters and may mix with parameters for self

    my $columns = $self->columns;
    $self->values_from_self($columns) if $self->{object};
    
    my @widgets;
    
    # if the form is in the context of a parent
    if ($self->{prev} && $self->{prev}{object}) {
        my $relationship = $self->{relation};
        my $parent_id = $self->{prev}{object}->get_column($relationship->{key});
        # edit the link object?
        if ($self->{object} && $relationship->{link_source}) {
            my $related_id = $self->{id};
            # fixme: object? if link has editable data?
            $self = SmartSea::Object->new({source => $relationship->{link_source}, app => $self->{app}});
            $columns = $self->columns;
            set_to_columns($columns, $relationship->{ref_to_related}, fixed => $related_id);
        }
        set_to_columns($columns, $relationship->{ref_to_parent}, fixed => $parent_id);
        set_to_columns($columns, $relationship->{set_to_null}, fixed => undef) if $relationship->{set_to_null};
    }

    # if the object has external sources for column values
    # example: dataset, if path is given, that can be examined
    $self->{object}->auto_fill_cols($self->{app}) if $self->{object} && $self->{object}->can('auto_fill_cols');

    # obtain default values for widgets
    $self->values_from_parameters($columns, $args->{input_is_fixed});

    # possible upgrade to subclass
    if (my $source = $self->subclass($columns)) {
        say STDERR "my class is $source";
        $self->{source} = $source;
        $self->{name} = $source;
        $self->{result} = 'SmartSea::Schema::Result::'.$self->{source};
        $self->{rs} = $self->{app}{schema}->resultset($source);
        $columns = $self->columns;
    }

    #my $title = $self->{object} ? 'Editing ' : 'Creating ';
    #$title .= $self->{object} ? $self->{object}->name : $self->{source};
    #unshift @widgets, [p => $title];

    # simple data from parent/upstream objects
    my %from_upstream; 
    my $obj = $self->first;
    while (my $next = $obj->next) {
        last unless $obj->{object};
        for my $key (keys %$columns) {
            next if $key eq 'id';
            next unless $obj->{object}->result_source->has_column($key);
            say STDERR "getting $key from upstream" if $self->{app}{debug} > 2;
            set_to_columns($columns, $key, from_up => $obj->{object}->$key);
        }
        $obj = $next;
    }

    my @unsaved;
    if ($self->{object}) {
        my %dirty = $self->{object}->get_dirty_columns;
        @unsaved = sort keys %dirty;
    } else {
        @unsaved = ('all');
    }

    my $compute = $self->{result}->can('compute_cols');
    
    if (my $super = $self->super) {
        push @widgets, [
            fieldset => [[legend => $super->{source}], $super->widgets($columns->{super}{columns})]
        ];
    }
    push @widgets, (
        $self->widgets($columns),
        button(name => 'request', value => 'save', content => 'Save'), 
        [1 => ' '], 
        button(content => 'Cancel'));
    push @widgets, (
        [1 => "&nbsp;&nbsp;&nbsp;"], 
        button(name => 'request', value => 'compute', content => 'Obtain values from data')
    ) if $compute;
    push @widgets, [1 => '&nbsp;&nbsp;There is unsaved data in columns: '.join(', ',@unsaved)] if @unsaved;
    return [fieldset => [[legend => $self->{source}], @widgets]];
}

sub compute_cols {
    my ($self) = @_;
    return unless $self->{result}->can('compute_cols');
    if ($self->{object}) {
        $self->{object}->compute_cols($self->{app});
    } else {
        $self->{result}->compute_cols($self->{app});
    }
}

sub widgets {
    my ($self, $columns) = @_;
    my @fcts;
    my @form;
    for my $column ($self->{result}->columns) {
        next if $column eq 'id';
        next if $column eq 'super';
        next unless exists $columns->{$column};
        my $meta = $columns->{$column};
        next if $meta->{system_column};
        say STDERR 
            "widget: $column => ",
            ($meta->{value}//'undef'),' ',
            ($meta->{is_part}//'reg') if $self->{app}{debug} > 2;
        
        my @input;
        $meta->{data_type} //= '';
        $meta->{html_input} //= '';

        if (exists $meta->{fixed} || $meta->{no_edit}) {
            my $value = exists $meta->{fixed} ? $meta->{fixed} : $meta->{value};
            my $id = $meta->{target} // 'id';
            my $val;
            if (defined $value) {
                if (ref $value) {
                    $val = $value->name;
                } elsif ($meta->{source}) {
                    $val = $self->{app}{schema}->
                        resultset($meta->{source})->
                        single({$id => $value})->name;
                }
                push @input, [p => [1 => "$column: $val"]] if defined $val;
                if (ref $value) {
                    $val = $value->$id;
                } else {
                    $val = $value;
                }
            }
            push @input, hidden($column => $val // '');
        } elsif ($meta->{html_input} eq 'textarea') {
            push @input, [1 => "$column: "], textarea(
                name => $column,
                rows => $meta->{rows},
                cols => $meta->{cols},
                value => $meta->{value} // ''
            );
        } elsif ($meta->{html_input} eq 'spinner') {
            push @input, [1 => "$column: "], spinner(
                name => $column,
                min => $meta->{min},
                max => $meta->{max},
                value => $meta->{value} // 1
                );
        } elsif ($meta->{is_foreign_key} && !$meta->{is_part}) {
            my $objs;
            if (ref $meta->{objs} eq 'ARRAY') {
                $objs = $meta->{objs};
            } elsif (ref $meta->{objs} eq 'CODE') {
                $objs = [];
                for my $obj ($self->{app}{schema}->resultset($meta->{source})->all) {
                    if ($meta->{objs}->($obj)) {
                        push @$objs, $obj;
                    }
                }
            } elsif (ref $meta->{objs} eq 'HASH') {
                $objs = [$self->{app}{schema}->resultset($meta->{source})->search($meta->{objs})];
            } else {
                $objs = [$self->{app}{schema}->resultset($meta->{source})->all];
            }
            my $id;
            if (defined $meta->{value}) {
                if (ref $meta->{value}) {
                    $id = $meta->{value}->id;
                } else {
                    $id = $meta->{value};
                }
            }
            push @input, [1 => "$column: "], drop_down(
                name => $column,
                objs => $objs,
                selected => $id,
                values => $meta->{values},
                not_null => $meta->{not_null}
                );
        } elsif ($meta->{data_type} eq 'boolean') {
            push @input, [1 => "$column: "], checkbox(
                name => $column,
                checked => $meta->{value} // $meta->{default} // 0
                );
        } else {
            # fallback data_type is text, integer, double
            push @input, [1 => "$column: "], text_input(
                name => $column,
                size => ($meta->{html_size} // 10),
                value => $meta->{value} // ''
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
            my $part = SmartSea::Object->new({source => $meta->{source}, object => $meta->{value}, app => $self->{app}});
            say STDERR "part ",($part->{object}//'undef') if $self->{app}{debug};
            my @style = $part->widgets($meta->{columns});
            push @form, [fieldset => {id => $column}, [[legend => $part->{source}], @style]];
        } else {
            my @content = @input;
            if ($meta->{from_up}) {
                my $info = ref $meta->{from_up} ? $meta->{from_up}->name : $meta->{from_up};
                push @content, [i => {style=>"color:grey"}, " ($info)"];
            }
            push @form, [ p => \@content ] if @input;
        }
    }
    if (@fcts) {
        push @form, [script => {src=>"http://code.jquery.com/jquery-1.10.2.js"}, ''];
        push @form, [script => join("\n",@fcts)];
    }
    return @form;
}

1;
