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

sub HTML_list {
    my (undef, $objs, %arg) = @_;
    my %data;
    my %li;
    for my $plan (@$objs) {
        my $p = $plan->title;
        $li{plan}{$p} = item([b => $p], $plan->id, %arg, ref => 'this plan');
        for my $use ($plan->uses) {
            my $u = $use->title;
            $data{$p}{$u} = 1;
            my $id = $plan->id.'/'.$use->id;
            $li{$p}{$u} = item($u, $id, %arg, action => 'None', ref => 'this use from this plan');
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
    my $action = $arg{action} eq 'Delete' ? 'create' : 'add';
    push @li, [li => a(link => "$action plan", url => $arg{uri}.'/new')] if $arg{edit};
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $oids, %arg) = @_;
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
    my @div = ([ul => \@l]);
    my $associated_class = 'SmartSea::Schema::Result::Use';
    $arg{action} = 'Remove';
    if (@$oids) {
        my $oid = shift @$oids;
        if (not defined $oid) {
            push @div, $associated_class->HTML_list([$self->uses]);
            push @div, [div => 'add here a form for adding an existing use into this plan'];
        } else {
            push @div, $self->uses->single({'use.id' => $oid})->HTML_div({}, $oids, %arg, plan => $self->id);
        }
    } else {
        push @div, $associated_class->HTML_list([$self->uses], %arg, plan => $self->id);
    }
    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $values, $oids, %arg) = @_;

    if (@$oids) {
        my $oid = shift @$oids;
        return $self->uses->single({'use.id' => $oid})->HTML_form($attributes, undef, $oids, %arg);
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
