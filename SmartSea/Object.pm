package SmartSea::Object;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use JSON;
use SmartSea::HTML qw(:all);

sub new {
    my ($class, %args) = @_;
    my $self = {schema => $args{schema}, url => singular($args{url})};
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
    } else {
        $w .= 's';
    }
    return $w;
}

sub open {
    my ($self, $oid) = @_;
    my ($class, $id) = split /:/, $oid;
    $class = singular($class);
    $self->{class_lc} = $class;
    $class =~ s/^(\w)/uc($1)/e;
    $class =~ s/_(\w)/uc($1)/e;
    if (defined $id) {
        eval {
            $self->{object} = $self->{schema}->resultset($class)->single({id => $id});
        };
        say STDERR "Error: $@" if $@;
    }
    $self->{class} = 'SmartSea::Schema::Result::'.$class;
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
    my ($class) = $self->{class} =~ /(\w+)$/;
    my $order_by = $self->{class}->can('order_by') ? $self->{class}->order_by : {-asc => 'name'};
    return [$self->{schema}->resultset($class)->search(undef, {order_by => $order_by})->all];
}

sub li {
    my ($self, $oids, $oids_index) = @_;

    my ($class) = $self->{class} =~ /(\w+)$/;

    my $url = $self->{url}.'/'.$self->{class_lc};
    unless ($self->{object}) {
        
        my @li;
        eval {
            for my $obj (@$oids) {
                my $name = $obj->name;
                push @li, [li => a(link => $name, url => $url.':'.$obj->id)];
            }
        };
        say STDERR "Error: $@" if $@;
        return [[b => plural($class)],[ul => \@li]];
    }

    my $attributes = $self->{object}->attributes;
    my @li;
    for my $a ('id', sort keys %$attributes) {
        my $v = $self->{object}->$a // '';
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
    my $need_arg = $self->{object}->relationship_methods;
    $url .= ':'.$self->{object}->id;
    for my $method (sort keys %$need_arg) {
        my $c = singular($method);
        my $child = SmartSea::Object->new(schema => $self->{schema}, url => $url);
        if ($#$oids >= $oids_index+1 && $oids->[$oids_index+1] =~ /$c/) {
            $child->open($oids->[$oids_index+1]);
        } else {
            $child->{class_lc} = $c;
            $c =~ s/^(\w)/uc($1)/e;
            $c =~ s/_(\w)/uc($1)/e;
            $child->{class} = 'SmartSea::Schema::Result::'.$c;
        }
        my $oids_or_children = $oids;
        unless ($child->{object}) {
            if ($need_arg->{$method}) {
                $oids_or_children = [$self->{object}->$method($oids)];
            } else {
                $oids_or_children = [$self->{object}->$method()];
            }
        }
        push @li, [li => $child->li($oids_or_children, $oids_index+1)];
    }
    return [[b => $class], [ul => \@li]];
}

1;
