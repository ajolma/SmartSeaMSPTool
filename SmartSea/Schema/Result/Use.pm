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
    my (undef, $objs, %arg) = @_;
    my ($uri, $edit, $context) = ($arg{uri}, $arg{edit}, $arg{context});
    my %li;
    for my $use (@$objs) {
        my $u = $use->title;
        $li{$u}{0} = item([b => $u], $use->id, %arg, ref => 'this use');
        for my $layer ($use->layers) {
            my $a = $layer->title;
            my $id = $use->id.'/layer:'.$layer->id;
            $li{$u}{layer}{$a} = item($a, $id, %arg, action => 'None', ref => 'this layer from this use');
        }
        for my $activity ($use->activities) {
            my $a = $activity->title;
            my $id = $use->id.'/activity:'.$activity->id;
            $li{$u}{activity}{$a} = item($a, $id, %arg, action => 'None', ref => 'this activity from this use');
        }
    }
    my @li;
    for my $use (sort keys %li) {
        my @l;
        for my $layer (sort keys %{$li{$use}{layer}}) {
            next unless $layer;
            push @l, [li => $li{$use}{layer}{$layer}];
        }
        my @a;
        for my $activity (sort keys %{$li{$use}{activity}}) {
            next unless $activity;
            push @a, [li => $li{$use}{activity}{$activity}];
        }
        my @item = @{$li{$use}{0}};
        my @s1 = (li => [[0=>'Layers'],[ul=>\@l]]);
        my @s2 = (li => [[0=>'Activities'],[ul=>\@a]]);
        my @s = (\@s1, \@s2);
        push @item, [ul => \@s];
        push @li, [li => \@item];
    }
    my $action = $arg{action} eq 'Delete' ? 'create' : 'add';
    push @li, [li => a(link => "$action use", url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $oids, %arg) = @_;
    my @l = ([li => [b => 'Use']]);
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
    $arg{action} = 'Remove';
    if (@$oids) {
        my $oid = shift @$oids;
        my $new = $oid =~ /new/;
        $oid =~ s/new//;
        if ($oid =~ /layer/) {
            $oid =~ s/layer://;
            if ($new) {
                push @div, SmartSea::Schema::Result::Layer->HTML_list([$self->layers], %arg, named_list => 1);
                my %layers = SmartSea::Schema::Result::Layer->hash($arg{schema});
                my @form = (
                    [0 => 'Select a layer type and press Add'],['br'],
                    [input => {type => 'hidden', name => 'use', value => $self->id}],
                    drop_down(name => 'layer', 
                              values => [sort {$layers{$a} cmp $layers{$b}} keys %layers], 
                              visuals => \%layers),['br'],
                    button(value => 'Add')
                    );
                my $uri = $arg{uri};
                $uri =~ s/\/layer:new//;
                push @div, [form => { action => $uri, method => 'POST' }, \@form];
            } else {
                $arg{context} = $arg{context} ? [$arg{context}, $self] : $self;
                push @div, $self->layers->single({'layer.id' => $oid})->HTML_div({}, $oids, %arg);
            }
        } elsif ($oid =~ /activity/) {
            $oid =~ s/activity://;
            if ($new) {
                push @div, SmartSea::Schema::Result::Activity->HTML_list([$self->activities], %arg, named_list => 1);
                push @div, [div => 'add here a form for adding an existing activity into this use'];
            } else {
                push @div, $self->activities->single({'activity.id' => $oid})->HTML_div({}, $oids, %arg);
            }
        }
    } else {
        if ($arg{parameters}{submit} && $arg{parameters}{submit} eq 'Add') {
            my $layer = $arg{schema}->resultset('Layer')->single({ id => $arg{parameters}{layer} });
            $self->add_to_layers($layer);
        }
        my @ul = (
            SmartSea::Schema::Result::Layer->HTML_list([$self->layers], %arg, named_item => 1),
            SmartSea::Schema::Result::Activity->HTML_list([$self->activities], %arg, named_item => 1)
        );
        push @div, [ul => \@ul];
    }
    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $values, $oids, %arg) = @_;

    if (@$oids) {
        my $oid = shift @$oids;
        if ($oid =~ /layer/) {
            $oid =~ s/layer://;
            return $self->layers->single({id => $oid})->HTML_form($attributes, undef, $oids, %arg);
        } elsif ($oid =~ /activity/) {
            $oid =~ s/activity://;
            return $self->activities->single({id => $oid})->HTML_form($attributes, undef, $oids, %arg);
        }
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
