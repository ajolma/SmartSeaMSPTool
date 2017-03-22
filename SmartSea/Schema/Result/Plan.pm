package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';

use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

my %attributes = (
    name =>            { i => 1,  input => 'text',    size => 20 },
    );

__PACKAGE__->table('plans');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'plan');
__PACKAGE__->many_to_many(uses => 'plan2use', 'use');

sub attributes {
    return \%attributes;
}

sub relationship_methods {
    return {plan2use => [plan2use => 0]};
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %data;
    my %li;
    for my $plan (@$objs) {
        my $p = $plan->name;
        $li{_plan}{$p} = item([b => $p], $plan->id, %args, ref => 'this plan');
        for my $use ($plan->uses) {
            my $u = $use->name;
            $data{$p}{uses}{$u} = 1;
            my $id = $plan->id.'/use:'.$use->id;
            $li{$p}{uses}{$u} = item($u, $id, %args, action => 'None');
        }
    }
    my @li;
    for my $plan (sort keys %{$li{_plan}}) {
        my @l;
        for my $use (sort keys %{$data{$plan}{uses}}) {
            push @l, [li => $li{$plan}{uses}{$use}];
        }
        my @item = @{$li{_plan}{$plan}};
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
            for my $b (qw/name id data/) {
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
