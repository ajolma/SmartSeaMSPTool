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
            croak 400 unless $tag;
            $args{class} = $tag;
            $args{source} = $app->{sources}{$tag};
            croak 404 unless $args{source};
            $args{name} = $args{source};
            
        } else {
            # object is parent, tag is relationship name
            $args{relation} = $object->relationship_hash->{$tag};
            croak 404 unless $args{relation};
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
            if ($prev) {
                croak 400 unless $prev->{row};
                $obj->{prev} = $prev;
                $prev->{next} = $obj;
                weaken($obj->{prev});
                weaken($prev->{next});
            }
            $prev = $obj;
        }
    }

    return @objects;
}

sub subclass_object {
    my ($object, $schema) = @_;
    if ($object && $object->can('subclass')) {
        my $subclass = $object->subclass;
        if ($subclass) {
            my $object2 = $schema->resultset($subclass)->single({super => $object->id});
            if ($object2) {
                return subclass_object($object2, $schema);
            } else {
                say STDERR "missing subclass object for $object:".$object->id;
            }
        }
    }
    return $object;
}

# in args give object, or source and possibly id or search
# polymorphic: returns the subclass object if this is one
sub new {
    my ($class, $args) = @_;
    confess "no app for object" unless $args->{app};
    my $self = {
        name => $args->{name}, # visual name
        relation => $args->{relation}, # hash of relation to parent
        stop_edit => $args->{stop_edit}, # user is not allowed to change this or this' children
        app => $args->{app}
    };
    if (defined $args->{row}) {
        #$self->{row} = subclass_object($args->{row}, $self->{app}{schema});
        $self->{row} = $args->{row};
        $self->{result} = ref $self->{row}; # result_source
        ($self->{source}) = $self->{result} =~ /(\w+)$/; # the last part of the Perl class
        $self->{rs} = $self->{app}{schema}->resultset($self->{source});
        $self->{id} = $self->{row}->id;
        
    } elsif ($args->{source}) {    
        my $result = 'SmartSea::Schema::Result::'.$args->{source};     
        my $rs = $self->{app}{schema}->resultset($args->{source});

        # existence of $self->{row} is significant
        # read returns schema if exists but not defined
        if ($args->{search}) { # needed for getting a link object in some cases
            if ($self->{app}{debug}) {
                for my $key (sort keys %{$args->{search}}) {
                    say STDERR "search term $key => $args->{search}{$key}";
                }
            }
            $self->{row} = $rs->single($args->{search});
            
        } elsif (defined $args->{id}) {

            # todo: this assumes first pk is id (maybe not named 'id' but anyway)
            my @pk = $result->primary_columns;
            if (@pk == 1) {
                @pk = ($args->{id});
            } elsif (@pk == 2) {
                # special case for rules, which have pk = id,cookie
                # 'find' of ResultSet for Rule is also replaced by 'my_find' to return default by default
                @pk = ($args->{id}, $self->{app}{cookie});
            } else {
                die "$self->{result}: more than two primary keys!";
            }
            $self->{row} = $rs->can('my_find') ? $rs->my_find(@pk) : $rs->find(@pk);

        }
        
        if ($self->{row}) {
            $self->{row} = subclass_object($self->{row}, $self->{app}{schema});
            $self->{id} = $self->{row}->id;
            $self->{result} = ref $self->{row}; # result_source
            ($self->{source}) = $self->{result} =~ /(\w+)$/; # the last part of the Perl class
            $self->{rs} = $self->{app}{schema}->resultset($self->{source});
        } else {
            $self->{source} = $args->{source};
            $self->{result} = $result;
            $self->{rs} = $rs;
        }
        
    } else {
        confess "SmartSea::Object->new requires either row or source";
        
    }

    $self->{name} //= $self->{source};
    $self->{class} = source2class($self->{source});
    
    if (defined $args->{edit}) {
        $self->{edit} = $args->{edit};
    } elsif ($self->{app}{admin}) {
        $self->{edit} = 1;
    } elsif ($self->{app}{user} ne 'guest') {
        if ($self->{result}->can('owner')) {
            if ($self->{row}) {
                $self->{edit} = $self->{app}{user} eq $self->{row}->owner;
            } else {
                $self->{edit} = 1;
            }
        }
    } else {
        $self->{edit} = 0;
    }
    bless $self, $class;
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

sub link {
    my $self = shift;
    return unless $self->{row};
    my $prev = $self->{prev};
    if ($prev) {
        my $relationship = $self->{relation};
        if ($relationship and $relationship->{link_source}) {
            my $args = {
                source => $relationship->{link_source}, 
                search => {
                    $relationship->{ref_to_parent} => $prev->{row}->get_column($relationship->{key}),
                    $relationship->{ref_to_related} => $self->{id}},
                app => $self->{app}
            };
            my $link = SmartSea::Object->new($args);
            croak "There is no relationship between ",$prev->str," and ",$self->str,"."
                unless $link->{row};
            return $link;
        }
    }
    return undef;
}

sub str {
    my $self = shift;
    return $self->{source} unless $self->{row};
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
    #return unless $self->{row};
    return unless $self->{result}->has_column('super');
    my $info = $self->{result}->column_info('super');
    my $super = $self->{row} ? $self->{row}->super : undef;
    #return unless $super;
    return SmartSea::Object->new({
        row => $super,
        #name => $self->{name},
        source => $info->{source},
        relation => $self->{relation},
        stop_edit => $self->{stop_edit},
        app => $self->{app}});
}

sub subclass {
    my ($self, $columns) = @_;
    my $can = $self->{result}->can('subclass');
    if ($self->{row}) {
        return $self->{row}->subclass if $can;
    } elsif ($columns) {
        return $self->{result}->subclass($columns) if $can;
    } else {
        croak "Must have result object or column data to call subclass." unless $self->{row};
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
    my $prev = $self->{prev} ? $self->{prev}{row} : undef;
    my $row = $self->{row} ? $self->{row} : $self->{result};
    my $columns_info = $row->columns_info(undef, $prev);
    for my $column (keys %$columns_info) {
        my $meta = $columns_info->{$column};
        # clean the meta from previous values_from.. calls
        delete $meta->{value};
        delete $meta->{fixed};
        if ($meta->{is_superclass} || $meta->{is_part}) {
            my %args = (app => $self->{app});
            if ($self->{row}) {
                $args{row} = $self->{row}->$column;
            }
            $args{source} = $meta->{source} unless $args{row};
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
        next if $meta->{not_used};
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
        next if $meta->{not_used};
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
            if ($meta->{source}) {
                my $related = SmartSea::Object->new({source => $meta->{source}, id => $meta->{$key}, app => $self->{app}});
                if (defined $related->{row}) {
                    $meta->{$key} = $related->{row};
                } else {
                    push @errors, "$meta->{source}:$meta->{$key} does not exist" if $required;
                }
            } else {
                push @errors, "$self->{source}, column $column source meta data missing!";
            }
        }
    }
    return @errors;
}

sub values_from_self {
    my ($self, $columns) = @_;
    confess "no obj" unless $self->{row};
    for my $column (keys %$columns) {
        say STDERR "from self $column, used ",($columns->{$column}{not_used}?'no':'yes') if $self->{app}{debug} > 2;
        my $meta = $columns->{$column};
        next if $meta->{not_used};
        $meta->{value} = $self->{row}->$column;
        if ($meta->{columns}) {
            if ($meta->{value}) {
                my $part = SmartSea::Object->new({row => $meta->{value}, app => $self->{app}});
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
        next if $meta->{not_used};
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
    $url .= ':'.$self->{id} if $self->{row};
    while (my $next = $self->next) {
        $self = $next;
        $url .= '/'.$self->{relation}{related};
        $url .= ':'.$self->{id} if $self->{row};
    }
    if (exists $self->{row}) {
        my $columns = $self->columns;
        $self->values_from_self($columns) if $self->{row};
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
        #print STDERR Dumper $columns;
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
        if ($self->{source} eq 'Rule') {
            $search->{cookie} = '';
        }

        $url .= ':';
        if ($self->{prev} && $self->{prev}{row}) {
            my $method = $self->{relation}{related};
            for my $row ($self->{prev}{row}->$method($search)) {
                #next unless $row->ecosystem_component->name =~ /Vege/;
                my %json = (class => $self->{class}, id => $row->id, href => $url.$row->id.'?accept=json');
                $json{name} = $row->name if $row->can('name');
                push @rows, \%json;
            }
        } else {
            for my $row ($self->{rs}->search($search, {order_by => 'id'})) {
                my %json = (
                    class => $self->{class}, 
                    id => $row->id, 
                    href => $url.$row->id.'?accept=json'
                    );
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

    if ($self->{prev} && $self->{prev}{row} && !$columns) {
        my $relationship = $self->{relation};
        confess "no key" unless $relationship->{key};
        my $parent_id = $self->{prev}{row}->get_column($relationship->{key});
        
        if ($relationship->{stop_edit} && !$self->{id}) {
            # update link(s)
            # delete old
            my $method = $relationship->{related};
            my @links = $self->{prev}{row}->$method;
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
                    $link->{row}->delete if $link && $link->{row};
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
        if ($self->{row}) { # create a link
            
            if ($relationship->{link_source}) { # create a link object
                my $link = SmartSea::Object->new({source => $relationship->{link_source}, app => $self->{app}});
                my $columns = $link->columns;
                set_to_columns($columns, $relationship->{ref_to_parent}, value => $parent_id);
                set_to_columns($columns, $relationship->{ref_to_related}, value => $self->{id});
                my @errors = $link->values_from_parameters($columns);
                return @errors if @errors;
                $link->create($columns);

            } else {
                $self->{row}->update({$relationship->{ref_to_parent} => $parent_id});
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
        next if $meta->{not_used};
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
        next if $meta->{not_used};
        next if $column eq 'id' && $self->{app}{sequences};
        $values{$column} = $meta->{value} if exists $meta->{value};
        if ($self->{app}{debug} > 1) {
            my $value = $values{$column} // 'undef';
            $value = $value->id if ref $value;
            say STDERR "  $column => ",$value;
        }
    }
    if ($self->{result}->can('is_ok')) {
        my $error = $self->{result}->is_ok(\%values);
        croak $error if $error;
    }

    $self->{row} = $self->{rs}->create(\%values);
    $self->{id} = $self->{row}->id;
    $self->{id} = $self->{id}->id if ref $self->{id};
    say STDERR "created $self->{source}, id is ",$self->{id} if $self->{app}{debug};

    #with SQLite DB the cookie is set to 1 although its default is '' and it is undef in create
    #say STDERR 'cookie is ',$self->{row}->cookie;

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
        $object->{row} = $object->{rs}->create(\%value);
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

    confess "Update was requested for a non-existing $self->{source} object." unless $self->{row};

    # is it actually a link object that needs to be updated?
    my $link = $self->link;
    $self = $link if $link;

    say STDERR "update ",$self->str if $self->{app}{debug};
    
    my $columns = $self->columns;
    my $col_data = {};

    # create, update or delete embedded child objects
    my %delete;
    for my $col (keys %$columns) {
        my $meta = $columns->{$col};
        next unless $meta->{is_part};
        if ($meta->{not_null}) {
            my $child = $self->{row}->$col;
            $child = SmartSea::Object->new({row => $child, app => $self->{app}});
            $child->update;
        } elsif ($self->{app}{parameters}{$col.'_is'}) {
            # TODO: child parameters should be prefixed with child name
            my $child = $self->{row}->$col;
            unless ($child) {
                $child = SmartSea::Object->new({source => $meta->{source}, app => $self->{app}});
                $child->create;
                $col_data->{$col} = $child->{row}->id;
            } else {
                $child = SmartSea::Object->new({row => $child, app => $self->{app}});
                $child->update;
            }
        } else {
            $col_data->{$col} = undef;
            if (my $child = $self->{row}->$col) {
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
            unless (defined $related->{row}) {
                push @errors, "$meta->{source}:$col_data->{$col} does not exist";
            }
        } else {
            # 
        }
    }

    if ($self->{row}->can('is_ok')) {
        my $error = $self->{row}->is_ok($col_data);
        push @errors, $error if $error;
    }

    if ($self->{app}{debug} > 1) {
        for my $col (sort keys %$col_data) {
            say STDERR "  update $col => ",($col_data->{$col}//'undef');
        }
    }
    croak join(', ', @errors) if @errors;
    
    #fixme: move create, update or delete embedded child objects here
    
    $self->{row}->update($col_data);

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
    my $link = $self->link;
    if ($link) {
        say STDERR "delete link object" if $self->{app}{debug};
        $link->{row}->delete;
        return;
    }
    if ($self->{prev}) {
        my $relationship = $self->{relation};
        if ($relationship) {
            if ($self->{prev}{source} eq $self->{source}) {
                say STDERR "remove link ",$self->{prev}->str," -> ",$self->str if $self->{app}{debug};
                $self->{row}->update({$relationship->{ref_to_parent} => undef});
                return;
            }
        } else {
            croak "There is no relationship between ",$self->{prev}->str," and ",$self->str,".";
        }
    }

    say STDERR "delete ",$self->str if $self->{app}{debug};
    
    croak "A request to delete unexisting ".$self->{source}." object." unless $self->{row};

    # delete non-independent objects linked to this
    my $relships = $self->relationship_hash;
    for my $related (keys %$relships) {
        my $relationship = $relships->{$related};
        next if $relationship->{no_edit};
        next if $relationship->{stop_edit};
        for my $row ($self->{row}->$related) {
            my $obj = SmartSea::Object->new({row => $row, app => $self->{app}});
            $obj->delete;
        }
    }

    # delete links from this object to independent objects
    for my $related (keys %$relships) {
        my $relationship = $relships->{$related};
        next unless $relationship->{stop_edit};
        my $link_objects = $relationship->{link_objects};
        next unless $link_objects;
        for my $row ($self->{row}->$link_objects) {
            $row->delete;
        }
    }

    my $columns = $self->columns;
    
    my %delete;
    for my $col (keys %$columns) {
        my $meta = $columns->{$col};
        if ($meta->{is_foreign_key} && $meta->{is_part}) {
            my $child = $self->{row}->$col;
            next unless $child;
            $delete{$meta->{source}} = $child->id;
        }
    }
    $self->{row}->delete;

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
    
    delete $self->{row};
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
    my $search = {};
    if ($self->{source} eq 'Rule') {
        $search->{cookie} = '';
    }
    return [$self->{rs}->search($search, {order_by => $order_by})->all];
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
        next if $meta->{not_used};
        my $value = exists $meta->{value} ? $meta->{value} : introspection($meta);
        if ($meta->{columns}) {
            my $part = ref $value ? 
                SmartSea::Object->new({row => $value, app => $self->{app}}) :
                SmartSea::Object->new({source => $meta->{source}, app => $self->{app}});
            my $li = [$part->simple_items($meta->{columns})];
            push @li, [li => [[b => [1 => $meta->{source}]], [ul => $li]]];
        } else {
            $value //= '(undef)';
            if (blessed $value) {
                for my $key (qw/name id data/) {
                    if ($value->can($key)) {
                        $value = $value->$key;
                        last;
                    }
                }
            } elsif (ref $value) { # array
                $value = "[".join(',',@$value)."]";
            }
            push @li, [li => "$column: ",encode_entities_numeric($value)];
        }
    }
    return @li;
}

# return object as an item for HTML lists
sub item {
    my ($self, $children, $opt) = @_;
    $opt //= {};
    $opt->{url} //= '';
    $self->{edit} = 0 if $opt->{stop_edit};
    
    say STDERR "item for ",$self->str,", edit: $self->{edit}, url: $opt->{url}" if $self->{app}{debug};

    return $self->item_class($self->all, $opt) unless exists $self->{row};

    my $tag = $self->{relation} ? $self->{relation}{related} : ($self->superclass // $self->{class});
    my $url = $opt->{url}.'/'.$tag;

    confess "no class name " unless defined $self->{name};
    my $name = $self->{name};
    $name = $self->{relation}{name} if $self->{relation} && $self->{relation}{name};
    my @content = a(link => "Show all ".plural($name), url => $url);

    $url .= ':'.$self->{id} if $self->{row};
    # fixme: do not add edit if this made instead of a link object with nothing to edit
    push @content, [1 => ' '], a(link => 'edit this one', url => $url.'?request=edit') if $self->{edit};

    # fixme?
    my $columns = $self->columns; # this doesn't call columns for is_part objects with real object
    $self->values_from_self($columns) if $self->{row};

    my @li;

    my $link = $self->link;
    if ($link) {
        my $columns = $link->columns; # this doesn't call columns for is_part objects with real object
        $link->values_from_self($columns);
        push @li, [li => [[b => [1 => 'Link']], [ul => [$link->simple_items($columns)]]]];
    }
  
    push @li, $self->simple_items($columns); # so here all cols (also unused) are shown

    if ($self->{row} && $self->{row}->can('info')) {
        my $info = $self->{row}->info($self->{app});
        push @li, [li => $info] if $info;
    }
    
    push @li, $self->related_items({url => $url}) if $self->{row};
    
    return [[b => @content], [ul => \@li]];
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
        my $objs = [$self->{row}->$key];
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
                row => $obj,
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
    $self->values_from_self($columns) if $self->{row};
    
    my @widgets;
    
    # if the form is in the context of a parent
    if ($self->{prev}) {
        my $relationship = $self->{relation};
        my $parent_id = $self->{prev}{row}->get_column($relationship->{key});
        my $link = $self->link;
        if ($link) {
            say STDERR "form for $link->{source}" if $self->{app}{debug};
            my $related_id = $self->{id};
            $self = $link;
            $columns = $self->columns;
            $self->values_from_self($columns) if $self->{row};
            set_to_columns($columns, $relationship->{ref_to_related}, fixed => $related_id);
        } else {
            set_to_columns($columns, $relationship->{ref_to_parent}, fixed => $parent_id);
            set_to_columns($columns, $relationship->{set_to_null}, fixed => undef) if $relationship->{set_to_null};
        }
    }

    # if the object has external sources for column values
    # example: dataset, if path is given, that can be examined
    $self->{row}->auto_fill_cols($self->{app}) if $self->{row} && $self->{row}->can('auto_fill_cols');

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

    #my $title = $self->{row} ? 'Editing ' : 'Creating ';
    #$title .= $self->{row} ? $self->{row}->name : $self->{source};
    #unshift @widgets, [p => $title];

    # simple data from parent/upstream objects
    my %from_upstream; 
    my $obj = $self->first;
    while (my $next = $obj->next) {
        last unless $obj->{row};
        for my $key (keys %$columns) {
            next if $key eq 'id';
            next unless $obj->{row}->result_source->has_column($key);
            say STDERR "getting $key from upstream" if $self->{app}{debug} > 2;
            set_to_columns($columns, $key, from_up => $obj->{row}->$key);
        }
        $obj = $next;
    }

    my @unsaved;
    if ($self->{row}) {
        my %dirty = $self->{row}->get_dirty_columns;
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
        button(content => 'Cancel')
    );
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
    if ($self->{row}) {
        $self->{row}->compute_cols($self->{app});
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
        next if $meta->{not_used};
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
        } elsif (($meta->{is_foreign_key} || ($meta->{semantics} && $meta->{semantics}{is_foreign_key})) && !$meta->{is_part}) {
            my $objs = $meta->{semantics} ? $meta->{semantics}{objs} : $meta->{objs};
            if (ref $objs eq 'ARRAY') {
            } elsif (ref $objs eq 'CODE') {
                my @objs;
                for my $obj ($self->{app}{schema}->resultset($meta->{source})->all) {
                    if ($objs->($obj)) {
                        push @objs, $obj;
                    }
                }
                $objs = \@objs;
            } elsif (ref $objs eq 'HASH') {
                $objs = [$self->{app}{schema}->resultset($meta->{source})->search($objs)];
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
            my $values = $meta->{semantics} ? $meta->{semantics}{values} : $meta->{values};
            push @input, [1 => "$column: "], drop_down(
                name => $column,
                objs => $objs,
                selected => $id,
                values => $values,
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
            my $part = SmartSea::Object->new({source => $meta->{source}, row => $meta->{value}, app => $self->{app}});
            say STDERR "part ",($part->{row}//'undef') if $self->{app}{debug};
            my @style = $part->widgets($meta->{columns});
            push @form, [fieldset => {id => $column}, [[legend => $part->{source}], @style]];
        } else {
            my @content = @input;
            if ($meta->{from_up}) {
                my $info = ref $meta->{from_up} ? $meta->{from_up}->name : $meta->{from_up};
                push @content, [i => {style=>"color:grey"}, " ($info)"];
            }
            if ($meta->{comment}) {
                push @content, [i => {style=>"color:red"}, " ($meta->{comment})"];
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
