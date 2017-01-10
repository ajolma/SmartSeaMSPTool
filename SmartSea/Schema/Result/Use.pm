package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.uses');
__PACKAGE__->add_columns(qw/ id title current_allocation /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'use');
__PACKAGE__->many_to_many(plans => 'plan2use', 'plan');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'use');
__PACKAGE__->many_to_many(layers => 'use2layer', 'layer');
__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');
__PACKAGE__->belongs_to(current_allocation => 'SmartSea::Schema::Result::Dataset');

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %li;
    for my $use (@$objs) {
        my $u = $use->title;
        $li{$u}{0} = item([b => $u], $use->id, $uri, $edit, 'this use');
        for my $activity ($use->activities) {
            my $a = $activity->title;
            my $id = $use->id.'/'.$activity->id;
            $li{$u}{$a} = item($a, $id, $uri, $edit, 'this activity from this use');
        }
    }
    my @li;
    for my $use (sort keys %li) {
        my @l;
        for my $activity (sort keys %{$li{$use}}) {
            next unless $activity;
            push @l, [li => $li{$use}{$activity}];
        }
        my @item = @{$li{$use}{0}};
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }
    push @li, [li => a(link => 'add use', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $config, $oids) = @_;
    my @l = ([li => 'Use']);
    for my $a (qw/id title current_allocation/) {
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
    my $associated_class = 'SmartSea::Schema::Result::Activity';
    if (@$oids) {
        my $oid = shift @$oids;
        if (not defined $oid) {
            push @div, $associated_class->HTML_list([$self->activities]);
            push @div, [div => 'add here a form for adding an existing activity into this use'];
        } else {
            push @div, $self->activities->single({'activity.id' => $oid})->HTML_div({}, $config, $oids);
        }
    } else {
        push @div, $associated_class->HTML_list([$self->activities], $config->{uri}, $config->{edit});
    }
    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $config, $values, $oids) = @_;

    if (@$oids) {
        my $oid = shift @$oids;
        return $self->activities->single({'activity.id' => $oid})->HTML_form($attributes, $config, undef, $oids);
    }

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Use')) {
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
