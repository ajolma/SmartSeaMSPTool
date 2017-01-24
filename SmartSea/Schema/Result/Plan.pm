package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.plans');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'plan');
__PACKAGE__->many_to_many(uses => 'plan2use', 'use');

sub create_col_data {
    my ($class, $parameters) = @_;
    my %col_data;
    for my $col (qw/title/) {
        $col_data{$col} = $parameters->{$col};
    }
    return \%col_data;
}

sub update_col_data {
    my ($class, $parameters) = @_;
    my %col_data;
    for my $col (qw/title/) {
        $col_data{$col} = $parameters->{$col};
    }
    return \%col_data;
}

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    return SmartSea::Schema::Result::Use->get_object(%args) if @{$args{oids}};
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
        my $p = $plan->title;
        $li{plan}{$p} = item([b => $p], $plan->id, %args, ref => 'this plan');
        for my $use ($plan->uses) {
            my $u = $use->title;
            $data{$p}{$u} = 1;
            my $id = $plan->id.'/'.$use->id;
            $li{$p}{$u} = item($u, $id, %args, action => 'None');
        }
    }
    my @li;
    for my $plan (sort keys %{$li{plan}}) {
        my @l;
        for my $use (sort keys %{$data{$plan}}) {
            push @l, [li => $li{$plan}{$use}];
        }
        my @item = @{$li{plan}{$plan}};
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }

    if ($args{edit}) {
        my $title = text_input(name => 'title');
        push @li, [li => [$title, 
                          [0 => ' '],
                          button(value => 'Create', name => 'plan')]];
    }

    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l = ([li => [b => 'Plan']]);
    for my $a (qw/id title/) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/title name data op id/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    my $associated_class = 'SmartSea::Schema::Result::Use';
    if (my $oid = shift @{$args{oids}}) {
        push @l, $self->uses->single({'use.id' => $oid})->HTML_div({}, %args, plan => $self->id, named_item => 'Use');
    } else {
        if ($args{parameters}{request} eq 'add') { # add use
            my $use = $args{schema}->resultset('Use')->single({ id => $args{parameters}{use} });
            eval {
                $self->add_to_uses($use);
            };
        } elsif ($args{parameters}{request} eq 'remove') { # add use
            my $use = $args{schema}->resultset('Use')->single({ id => $args{parameters}{remove} });
            eval {
                $self->remove_from_uses($use);
            };
        }
        $args{action} = 'Remove';
        push @l, $associated_class->HTML_list([$self->uses], %args, plan => $self->id, named_item => 'Uses');
    }
    return [div => $attributes, [ul => \@l]];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    if (my $oid = shift @{$args{oids}}) {
        $args{plan} = $self->id;
        return $self->uses->single({'use.id' => $oid})->HTML_form($attributes, undef, %args);
    }

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Plan')) {
        for my $key (qw/title/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $title = text_input(
        name => 'title',
        size => 15,
        value => $values->{title} // ''
    );

    push @form, (
        [ p => [[1 => 'title: '],$title] ],
        button(value => "Store")
    );

    return [form => $attributes, @form];
}

1;
