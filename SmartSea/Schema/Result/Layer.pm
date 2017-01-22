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
__PACKAGE__->has_many(plan2use2layer => 'SmartSea::Schema::Result::Plan2Use2Layer', 'layer');
__PACKAGE__->many_to_many(plan2uses => 'plan2use2layer', 'plan2use');

sub HTML_list {
    my (undef, $objs, %arg) = @_;
    my %li;
    my %has;
    for my $layer (@$objs) {
        my $u = $layer->title;
        my $id = $layer->id;
        $has{$id} = 1;
        $li{$u}{0} = item([b => $u], "layer:$id", %arg, ref => 'this layer');
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

    if ($arg{edit}) {
        my @objs;
        for my $obj ($arg{schema}->resultset('Layer')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        if (@objs) {
            my $drop_down = drop_down(name => 'layer', objs => \@objs);
            push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'layer')]];
        }
    }

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
    
    if (@$oids) {
        my $oid = shift @$oids;
        push @div, $arg{schema}->resultset('Rule')->single({id => $oid})->HTML_div({}, $oids, %arg);
    } elsif ($arg{plan2use}) {
        my $pul = $arg{schema}->
            resultset('Plan2Use2Layer')->
            single({plan2use => $arg{plan2use}, layer => $self->id});
        my @rules = $pul->rules->search({'me.cookie' => DEFAULT});
        $arg{pul} = $pul->id;
        my $list = SmartSea::Schema::Result::Rule->HTML_list(\@rules, %arg);
        my $rule_class = $pul->rule_class;
        my @list;
        push @list, (
            [0 => "Rules are applied "], 
            drop_down(name => 'rule_class',
                      objs => [$arg{schema}->
                               resultset('RuleClass')->all], 
                      selected => $rule_class->id),
            button(value => 'Update', name => 'pul')) if $rule_class;
        push @list, $list;
        push @div, [ul => [li => @list]];
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
