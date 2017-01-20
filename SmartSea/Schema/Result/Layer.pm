package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.layers');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'layer');
__PACKAGE__->many_to_many(uses => 'use2layer', 'use');

sub hash {
    my (undef, $schema) = @_;
    my %layers;
    for my $l ($schema->resultset('Layer')->all) {
        $layers{$l->id} = $l->title;
    }
    return %layers;
}

sub HTML_list {
    my (undef, $objs, %arg) = @_;
    my ($uri, $edit) = ($arg{uri}, $arg{edit});
    my %li;
    for my $layer (@$objs) {
        my $u = $layer->title;
        $li{$u}{0} = item([b => $u], "layer:".$layer->id, %arg, ref => 'this layer');
    }
    my @li;
    for my $use (sort keys %li) {
        my @l;
        for my $layer (sort keys %{$li{$use}}) {
            next unless $layer;
            push @l, [li => $li{$use}{$layer}];
        }
        my @item = @{$li{$use}{0}};
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }
    push @li, [li => a(link => 'add layer', url => $uri.'/layer:new')] if $edit;
    my $ret = [ul => \@li];
    return [ ul => [ [li => 'Layers'], $ret ]] if $arg{named_list};
    return [ li => [ [0 => 'Layers'], $ret ]] if $arg{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, $oids, %arg) = @_;
    my @l = ([li => [b => 'Layer']]);
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
    
    # todo: add rules if context = [plan, use]
    if (ref $arg{context} eq 'ARRAY' &&
        ref $arg{context}[0] eq 'SmartSea::Schema::Result::Plan' &&
        ref $arg{context}[1] eq 'SmartSea::Schema::Result::Use') 
    {
        if (@$oids) {
            my $oid = shift @$oids;
            push @div, $arg{schema}->resultset('Rule')->single({id => $oid})->HTML_div({}, $oids, %arg);
        } else {
            my @rules = $arg{schema}->resultset('Rule')->search(
                {-and => [
                      plan => $arg{context}[0]->id,
                      use => $arg{context}[1]->id,
                      layer => $self->id,
                      cookie => DEFAULT
                     ]});
            push @div, SmartSea::Schema::Result::Rule->HTML_list(\@rules, %arg);
        }
    }

    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $values, $oids, %arg) = @_;
    if (@$oids) {
        my $oid = shift @$oids;
        $arg{schema}->resultset('Rule')->single({id => $oid})->HTML_form($attributes, undef, $oids, %arg);
    }
}

1;
