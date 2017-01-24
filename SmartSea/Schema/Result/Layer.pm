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

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    $oid =~ s/^\w+://;
    return SmartSea::Schema::Result::Rule->get_object(%args) if @{$args{oids}};
    my $obj;
    eval {
        $obj = $args{schema}->resultset('Layer')->single({id => $oid});
    };
    say STDERR "Error: $@" if $@;
    return $obj;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %li;
    my %has;
    for my $layer (@$objs) {
        my $u = $layer->title;
        my $id = $layer->id;
        $has{$id} = 1;
        $li{$u}{0} = item([b => $u], "layer:$id", %args, ref => 'this layer');
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

    if ($args{edit}) {
        my @objs;
        for my $obj ($args{schema}->resultset('Layer')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        if (@objs) {
            my $drop_down = drop_down(name => 'layer', objs => \@objs);
            push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'layer')]];
        }
    }

    my $ret = [ul => \@li];
    return [ ul => [ [li => 'Layers'], $ret ]] if $args{named_list};
    return [ li => [ [0 => 'Layers'], $ret ]] if $args{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    push @l, ([li => [b => 'Layer']]) unless $args{plan};
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

    my $pul = $args{plan2use} ? $args{schema}->
        resultset('Plan2Use2Layer')->
        single({plan2use => $args{plan2use}, layer => $self->id}) : undef;

    push @l, [li => "Rule class: ".$pul->rule_class->title] if $pul;
    
    if (my $oid = shift @{$args{oids}}) {
        $args{named_item} = 'Rule';
        push @l, $args{schema}->resultset('Rule')->single({id => $oid})->HTML_div({}, %args);
    } elsif ($pul) {
        
        my @rules;

        if ($args{parameters}{request} eq 'update') {
            eval {
                $pul->update({rule_class => $args{parameters}{rule_class} });
            };
        } elsif ($args{parameters}{request} eq 'add') {
            @rules = $pul->rules->search({'me.cookie' => DEFAULT});
            my $index = (scalar(@rules) // 0)+1;
            eval {
                $args{schema}->resultset('Rule')->create(
                    SmartSea::Schema::Result::Rule->create_col_data(
                        $args{parameters}, 
                        {cookie => DEFAULT, plan2use2layer => $pul->id, my_index => $index}));
            };
            say STDERR "error: $@" if $@;
        } elsif ($args{parameters}{request} eq 'remove') {
            my $remove = $args{parameters}{remove};
            my $rule = $args{schema}->resultset('Rule')->single({ id => $remove });
            eval {
                $rule->delete;
            };
            say STDERR "error: $@" if $@;
        }
        @rules = $pul->rules->search({'me.cookie' => DEFAULT});

        my $rule_class = $pul->rule_class;
        push @l, [ li => 
                   [0 => "Rules are applied "], 
                   drop_down(name => 'rule_class',
                             objs => [$args{schema}->
                                      resultset('RuleClass')->all], 
                             selected => $rule_class->id),
                   button(value => 'Update', name => 'pul') ];
        
        $args{pul} = $pul->id;
        $args{action} = 'Delete';
        $args{rule_class} = $pul->rule_class->title;
        push @l, SmartSea::Schema::Result::Rule->HTML_list(\@rules, %args, named_list => 1);
    }
    return [ li => [0 => 'Layer:'], [ul => \@l] ] if $args{named_item};
    return [ div => $attributes, [ul => \@l] ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;
    if (my $oid = shift @{$args{oids}}) {
        my $pul = $args{schema}->
            resultset('Plan2Use2Layer')->
            single({plan2use => $args{plan2use}, layer => $self->id});
        my $rule = $args{schema}->resultset('Rule')->single({id => $oid});
        $args{rule_class} = $pul->rule_class->title;
        $rule->HTML_form($attributes, undef, %args);
    }
}

1;
