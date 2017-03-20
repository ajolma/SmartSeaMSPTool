package SmartSea::Schema::Result::LayerClass;
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

__PACKAGE__->table('layer_classes');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(layers => 'SmartSea::Schema::Result::Layer', 'layer_class');
__PACKAGE__->many_to_many(plan2uses => 'layer', 'plan2use');

sub attributes {
    return \%attributes;
}

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    $oid =~ s/^\w+://;
    return SmartSea::Schema::Result::Rule->get_object(%args) if @{$args{oids}};
    my $obj;
    eval {
        $obj = $args{schema}->resultset('LayerClass')->single({id => $oid});
    };
    say STDERR "Error: $@" if $@;
    return $obj;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %li;
    my %has;
    for my $layer (@$objs) {
        my $u = $layer->name;
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
        if ($args{plan}) {
            my @objs;
            for my $obj ($args{schema}->resultset('LayerClass')->all) {
                next if $has{$obj->id};
                push @objs, $obj;
            }
            if (@objs) {
                my $drop_down = drop_down(name => 'layer', objs => \@objs);
                push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'layer')]];
            }
        } else {
            my $name = text_input(name => 'name');
            push @li, [li => [$name, 
                              [0 => ' '],
                              button(value => 'Create', name => 'layer')]];
        }
    }

    my $ret = [ul => \@li];
    return [ ul => [ [li => 'Layers'], $ret ]] if $args{named_list};
    return [ li => [ [0 => 'Layers'], $ret ]] if $args{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;

    my $pul = $args{plan2use} ? $args{schema}->
        resultset('Layer')->
        single({plan2use => $args{plan2use}, layer => $self->id}) : undef;

    if ($pul) {
        if ($args{parameters}{request} eq 'update') {
            my %update = ();
            for my $field (qw/style rule_class min_value max_value classes/) {
                my $val = $args{parameters}{$field};
                $val = undef if $val eq '';
                $update{$field} = $val;
            }
            eval {
                $pul->update(\%update);
            };
        } elsif ($args{parameters}{request} eq 'add') {
            my @rules = $pul->rules->search({'me.cookie' => DEFAULT});
            my $index = (scalar(@rules) // 0)+1;
            eval {
                $args{schema}->resultset('Rule')->create(
                    SmartSea::Schema::Result::Rule->create_col_data(
                        $args{parameters}, 
                        {cookie => DEFAULT, plan2use2layer => $pul->id, my_index => $index}));
            };
        } elsif ($args{parameters}{request} eq 'remove') {
            my $remove = $args{parameters}{remove};
            my $rule = $args{schema}->resultset('Rule')->single({ id => $remove });
            eval {
                $rule->delete;
            };
        }
        say STDERR "error: $@" if $@;
    }

    my @l;
    push @l, ([li => [b => 'Layer']]) unless $args{plan};
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

    my $rule_class = $pul ? $pul->rule_class : undef;
    push @l, [li => "Max value: ".$pul->additive_max] if $pul && $rule_class->name =~ /^add/;
    
    if (my $oid = shift @{$args{oids}}) {
        $args{named_item} = 'Rule';
        push @l, $args{schema}->resultset('Rule')->single({id => $oid})->HTML_div({}, %args);
    } elsif ($pul) {
        my @rules = $pul->rules->search({'me.cookie' => DEFAULT});

        if ($args{edit}) {
            my @items = (
                [0 => "Color palette is "], 
                drop_down(name => 'style',
                          objs => [$args{schema}->
                                   resultset('ColorScale')->all], 
                          selected => $pul->style->id),
                ['br'],
                [0 => "Rules are "], 
                drop_down(name => 'rule_class',
                          objs => [$args{schema}->
                                   resultset('RuleClass')->all], 
                          selected => $rule_class->id),
                ['br'],
                [0 => " Min value is "], 
                text_input(name => 'min_value',
                           value => $pul->min_value),
                ['br'],
                [0 => " Max value is "], 
                text_input(name => 'max_value',
                           value => $pul->max_value),
                ['br'],
                [0 => " Nr of classes is "], 
                text_input(name => 'classes',
                           value => $pul->classes),
                ['br'],
                [0 => " "], button(value => 'Update', name => 'pul')
                );
            push @l, [ li => @items ];
        } else {
            push @l, [ li => "Color palette is ".$pul->style->name ];
            push @l, [ li => "Rules are ".$rule_class->name ];
        }
        
        $args{pul} = $pul->id;
        $args{action} = 'Delete';
        $args{rule_class} = $rule_class->name;
        push @l, SmartSea::Schema::Result::Rule->HTML_list(\@rules, %args, named_list => 1);
    }
    return [ li => [0 => 'Layer:'], [ul => \@l] ] if $args{named_item};
    return [ div => $attributes, [ul => \@l] ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;
    if (my $oid = shift @{$args{oids}}) {
        my $pul = $args{schema}->
            resultset('Layer')->
            single({plan2use => $args{plan2use}, layer => $self->id});
        my $rule = $args{schema}->resultset('Rule')->single({id => $oid});
        $args{rule_class} = $pul->rule_class->name;
        return $rule->HTML_form($attributes, undef, %args);
    }

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::LayerClass')) {
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
