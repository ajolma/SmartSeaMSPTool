package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.plans');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'plan');
__PACKAGE__->many_to_many(uses => 'plan2use', 'use');
__PACKAGE__->has_many(plan2dataset => 'SmartSea::Schema::Result::Plan2Dataset', 'plan');
__PACKAGE__->many_to_many(datasets => 'plan2dataset', 'dataset');

sub create_col_data {
    my ($class, $parameters) = @_;
    my %col_data;
    for my $col (qw/name/) {
        $col_data{$col} = $parameters->{$col};
    }
    return \%col_data;
}

sub update_col_data {
    my ($class, $parameters) = @_;
    my %col_data;
    for my $col (qw/name/) {
        $col_data{$col} = $parameters->{$col};
    }
    return \%col_data;
}

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    if (@{$args{oids}}) {
        if ($args{oids}->[0] =~ /use/) {
            $args{oids}->[0] =~ s/use://;
            return SmartSea::Schema::Result::Use->get_object(%args);
        } elsif ($args{oids}->[0] =~ /dataset/) {
            $args{oids}->[0] =~ s/dataset://;
            return SmartSea::Schema::Result::Dataset->get_object(%args);
        }
    }
    my $obj;
    eval {
        $obj = $args{schema}->resultset('Plan')->single({id => $oid});
    };
    say STDERR "Error: $@" if $@;
    return $obj;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %data;
    my %li;
    for my $plan (@$objs) {
        my $p = $plan->name;
        $li{plan}{$p} = item([b => $p], $plan->id, %args, ref => 'this plan');
        for my $use ($plan->uses) {
            my $u = $use->name;
            $data{$p}{uses}{$u} = 1;
            my $id = $plan->id.'/use:'.$use->id;
            $li{$p}{uses}{$u} = item($u, $id, %args, action => 'None');
        }
        for my $dataset ($plan->datasets) {
            my $u = $dataset->name;
            $data{$p}{datasets}{$u} = 1;
            my $id = $plan->id.'/dataset:'.$dataset->id;
            $li{$p}{datasets}{$u} = item($u, $id, %args, action => 'None');
        }
    }
    my @li;
    for my $plan (sort keys %{$li{plan}}) {
        my @l;
        for my $use (sort keys %{$data{$plan}{uses}}) {
            push @l, [li => $li{$plan}{uses}{$use}];
        }
        for my $dataset (sort keys %{$data{$plan}{datasets}}) {
            push @l, [li => $li{$plan}{datasets}{$dataset}];
        }
        my @item = @{$li{plan}{$plan}};
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }

    if ($args{edit}) {
        my $name = text_input(name => 'name');
        push @li, [li => [$name, 
                          [0 => ' '],
                          button(value => 'Create', name => 'plan')]];
    }

    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l = ([li => [b => 'Plan']]);
    for my $a (qw/id name/) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/id name data/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    $args{plan} = $self->id;
    $args{named_item} = 1;
    my $error;
    if (my $oid = shift @{$args{oids}}) {
        if ($oid =~ /use/) {
            $oid =~ s/use://;
            push @l, $self->uses->single({'use.id' => $oid})->HTML_div({}, %args);
        } elsif ($oid =~ /dataset/) {
            $oid =~ s/dataset://;
            push @l, $self->datasets->single({'dataset.id' => $oid})->HTML_div({}, %args);
        }
    } else {
        if ($args{parameters}{request} eq 'add') {
            if ($args{parameters}{add} eq 'use') {
                my $use = $args{schema}->resultset('Use')->single({ id => $args{parameters}{use} });
                eval {
                    $self->add_to_uses($use);
                };
                $error = $@;
                say STDERR $@ if $@;
            } elsif ($args{parameters}{add} eq 'dataset') {
                my $dataset = $args{schema}->resultset('Dataset')->single({ id => $args{parameters}{dataset} });
                eval {
                    $self->add_to_datasets($dataset);
                };
                $error = $@;
                say STDERR $@ if $@;
            }
        } elsif ($args{parameters}{request} eq 'remove') {
            if ($args{parameters}{remove} =~ /^use:(\d+)/) {
                my $use = $args{schema}->resultset('Use')->single({ id => $1 });
                eval {
                    $self->remove_from_uses($use);
                };
                $error = $@;
                say STDERR $@ if $@;
            } elsif ($args{parameters}{remove} =~ /^dataset:(\d+)/) {
                my $dataset = $args{schema}->resultset('Dataset')->single({ id => $1 });
                eval {
                    $self->remove_from_datasets($dataset);
                };
                $error = $@;
                say STDERR $@ if $@;
            }
        }
        $args{action} = 'Remove';
        push @l, SmartSea::Schema::Result::Use->HTML_list([$self->uses], %args);
        push @l, SmartSea::Schema::Result::Dataset->HTML_list([$self->datasets], %args);
    }
    my @content;
    push @content, [0 => $error] if $error;
    push @content, [ul => \@l];
    return [div => $attributes, @content];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    if (my $oid = shift @{$args{oids}}) {
        $args{plan} = $self->id;
        return $self->uses->single({'use.id' => $oid})->HTML_form($attributes, undef, %args);
    }

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Plan')) {
        for my $key (qw/name/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $name = text_input(
        name => 'name',
        size => 15,
        value => $values->{name} // ''
    );

    push @form, (
        [ p => [[1 => 'name: '],$name] ],
        button(value => "Store")
    );

    return [form => $attributes, @form];
}

1;
