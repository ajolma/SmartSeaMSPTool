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
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    my %li;
    for my $plan (@$objs) {
        my $p = $plan->title;
        $li{plan}{$p} = item([b => $p], $plan->id, $uri, $edit, 'this plan');
        for my $use ($plan->uses) {
            my $u = $use->title;
            $data{$p}{$u} = 1;
            my $id = $plan->id.'/'.$use->id;
            $li{$p}{$u} = item($u, $id, $uri, $edit, 'this use from this plan');
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
    push @li, [li => a(link => 'add plan', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $config, $oids) = @_;
    my @l = ([li => 'Plan']);
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
    if (@$oids) {
        my $oid = shift @$oids;
        if (not defined $oid) {
            push @div, $associated_class->HTML_list([$self->uses]);
            push @div, [div => 'add here a form for adding an existing use into this plan'];
        } else {
            push @div, $self->uses->single({'use.id' => $oid})->HTML_div({}, $config, $oids);
        }
    } else {
        push @div, $associated_class->HTML_list([$self->uses], $config->{uri}, $config->{edit});
    }
    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $config, $values, $oids) = @_;

    if (@$oids) {
        my $oid = shift @$oids;
        return $self->uses->single({'use.id' => $oid})->HTML_form($attributes, $config, undef, $oids);
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
