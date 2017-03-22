package SmartSea::Object;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;
use SmartSea::HTML qw(:all);

sub new {
    my ($class, $args) = @_;
    my $self = {
        schema => $args->{schema}, 
        url => singular($args->{url}), 
        edit => $args->{edit},
        dbname => $args->{dbname},
        user => $args->{user},
        pass => $args->{pass},
        data_dir => $args->{data_dir},
        class_lc => undef,
        source => undef,
        class => undef,
        class_name => undef,
        rs => undef,
        object => undef,
    };
    bless $self, $class;
}

sub create {
    my ($class, $data, $schema, $col) = @_;
    my $_class = 'SmartSea::Schema::Result::'.$class;
    my $attributes = $_class->attributes;
    my %update_data;
    my %unused_data;
    for my $col (keys %$attributes) {
        if ($attributes->{$col}{input} eq 'object') {
            $data = create($attributes->{$col}{class}, $data, $schema, $col);
        }
    }
    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        if (exists $data->{$col}) {
            if ($attributes->{$col}{empty_is_null} && $data->{$col} eq '') {
                $data->{$col} = undef;
            }
        }
    }
    say STDERR "create $class";
    for my $col (keys %$data) {
        if (exists $attributes->{$col}) {
            $update_data{$col} = $data->{$col};
        } else {
            $unused_data{$col} = $data->{$col};
        }
    }
    my $rs = $schema->resultset($class);
    my $obj;
    eval {
        $obj = $rs->create(\%update_data);
    };
    say STDERR "Error: $@" if $@;
    say STDERR "id for $col is ",$obj->id if defined $col;
    $unused_data{$col} = $obj->id if defined $col;
    return \%unused_data;
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

sub set_class {
    my ($self, $class) = @_;
    $self->{class_lc} = $class;
    $class =~ s/^(\w)/uc($1)/e;
    $class =~ s/_(\w)/uc($1)/e;
    $class =~ s/(\d\w)/uc($1)/e;
    $self->{source} = $class;
    $self->{class} = 'SmartSea::Schema::Result::'.$class;
    $self->{class_name} = $self->{class}->can('class_name') ? 
        $self->{class}->class_name : $self->{source};
}

sub open {
    my ($self, $oid) = @_;
    my ($class, $id) = split /:/, $oid;
    $self->set_class(singular($class));
    eval {
        $self->{rs} = $self->{schema}->resultset($self->{source});
        if (defined $id) {
            $self->{object} = $self->{rs}->single({id => $id});
        }
    };
    say STDERR "Error: $@" if $@;
    return $@ ? 0 : 1;
}

sub update {
    my ($self, $data) = @_;
    my $attributes = $self->attributes;
    my %update_data;
    my %unused_data;
    for my $col (keys %$attributes) {
        if ($attributes->{$col}{input} eq 'object') {
            my $obj = $self->$col;
            $data = update($obj, $data);
        }
    }
    for my $col (keys %$attributes) {
        next if $attributes->{$col}{input} eq 'object';
        if (exists $data->{$col}) {
            if ($attributes->{$col}{empty_is_null} && $data->{$col} eq '') {
                $data->{$col} = undef;
            }
        }
    }
    say STDERR "update $self";
    for my $col (keys %$data) {
        if (exists $attributes->{$col} && $attributes->{$col}{input} ne 'object') {
            $update_data{$col} = $data->{$col};
        } else {
            $unused_data{$col} = $data->{$col};
        }
    }
    $self->update(\%update_data);
    return \%unused_data;
}

sub delete {
    my ($self) = @_;
    my $attributes = $self->attributes;
    my %delete;
    for my $col (keys %$attributes) {
        if ($attributes->{$col}{input} eq 'object') {
            $delete{$col} = $self->$col;
        }
    }
    eval {
        $self->delete;
    };
    say STDERR "Error: $@" if $@;
    for my $col (keys %$attributes) {
        delete($delete{$col})
    }
}

sub all {
    my ($self) = @_;
    # todo: impacts resultset list
    return [$self->{rs}->list] if $self->{rs}->can('list');
    # todo: use self->rs and methods in it below
    my $order_by = $self->{class}->can('order_by') ? $self->{class}->order_by : {-asc => 'name'};
    return [$self->{rs}->search(undef, {order_by => $order_by})->all];
}

sub li {
    my ($self, $oids, $oids_index) = @_;

    # todo: ecosystem component has an expected impact, which can be computed

    my $attributes = $self->{class}->can('attributes') ? $self->{class}->attributes : undef;
    my $editable = $attributes && $self->{edit};
    $attributes //= {};

    my $url = $self->{url}.'/'.$self->{class_lc};
    unless ($self->{object}) {

        #say STDERR "list ",$self->{class_name};
        my @li;
        for my $obj (@$oids) {
            my $name = $obj->name;
            my @content = a(link => $name, url => $url.':'.$obj->id);
            if ($editable) {
                push @content, [1 => ' '], a(link => 'edit', url => $url.':'.$obj->id.'?edit');
            }
            if ($self->{edit}) {
                push @content, [1 => ' '], button(value => 'Remove'); # to do: remove or delete? in form
            }
            push @li, [li => @content];
        }
        if ($self->{edit}) {
            my @content;
            push @content, $oids_index->{for_add}, [0=>' '] if $oids_index && $oids_index->{for_add};
            push @content, button(value => 'Add');
            push @li, [li => [form => {action => $url, method => 'POST'}, @content]];
        }
        return [[b => plural($self->{class_name})],[ul => \@li]];
        
    }
    
    my $object = $self->{object};
    #say STDERR "object ",$object->id;

    my @content = a(link => $self->{class_name}, url => plural($url));
    $url .= ':'.$object->id;
    if ($editable) {
        push @content, [1 => ' '], a(link => 'edit', url => $url.'?edit');
    }
    
    my @li = ([li => "id: ".$object->id], [li => "name: ".$object->name]);
    my $children_listers;
    $children_listers = $object->children_listers if $object->can('children_listers');
    # simple attributes:
    for my $a (sort keys %$attributes) {
        next if $a eq 'name';
        next if $children_listers->{$a};
        # todo what if style, ie object?
        # todo: for rules show only relevant ones
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
    push @li, [li => $object->info($self)] if $object->can('info');
    # children, which can be 
    # open - there is $oids->[$oids_index], it opens an object, whose id is in what the method returns - or 
    # closed - otherwise
    # the method can be built-in (0), in result (1) or in result_set (2)
    for my $lister (sort keys %$children_listers) {
        my ($class_of_child, $lister_type) = @{$children_listers->{$lister}};
        my %args = %{$self};
        $args{url} = $url;
        my $child = SmartSea::Object->new(\%args);
        if ($#$oids >= $oids_index+1) {
            $child->open($oids->[$oids_index+1]);
        } else {
            $child->set_class($class_of_child);
        }
        my $children;
        if ($lister_type == 2) {
            $children = [$self->{rs}->$lister($object)];
            $child->{class_name} = $lister;
            $child->{class_name} =~ s/^(\w)/uc($1)/e;
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
        if ($child_is_open) {
            push @li, [li => $child->li($oids, $oids_index+1)];
        } else {
            delete $child->{object};
            my %opt = (for_add => $self->for_child_form($lister, $children));
            push @li, [li => $child->li($children, \%opt)];
        }
    }
    
    return [[b => @content], [ul => \@li]];
}

sub for_child_form {
    my ($self, $lister, $children) = @_;
    if ($self->{object}->can('for_child_form')) {
        return $self->{object}->for_child_form($lister, $children, $self);
    }
}

sub form {
    my ($self, $oids, $values) = @_;
    my $attributes = $self->{class}->attributes;
    my @widgets;
    # todo: tell the context, from oids
    if ($self->{object}) {
        # todo: add parent data for information
        for my $key (keys %$attributes) {
            next unless defined $self->{object}->$key;
            next if defined $values->{$key};
            $values->{$key} = $self->{object}->$key;
        }

        # todo: dataset have in-form button for computing min and max
        # that returns here and changes values
        # my $b = Geo::GDAL::Open($args{data_dir}.$self->path)->Band;
        #    $b->ComputeStatistics(0);
        #    $values->{min} = $b->GetMinimum;
        #    $values->{max} = $b->GetMaximum;
        
        push @widgets, hidden(id => $self->{object}->id);
        push @widgets, hidden(source => $self->{source});
    } else {
        push @widgets, 
        [p => {style => 'color:red'}, 
         'Filled data is from parent objects and for information only. Please delete or overwrite them.'] 
            if @$oids > 1;
        for (my $oid = 0; $oid < @$oids-1; ++$oid) {
            my $obj = SmartSea::Object->new($self);
            $obj->open($oids->[$oid]);
            for my $key (keys %$attributes) {
                next unless defined $obj->{object}->$key;
                next if defined $values->{$key};
                $values->{$key} = $obj->{object}->$key;
            }
        }
    }
    push @widgets, widgets($attributes, $values, $self->{schema});
    push @widgets, button(value => 'Save'), [1 => ' '], button(value => 'Cancel');
    return @widgets;
}

1;
