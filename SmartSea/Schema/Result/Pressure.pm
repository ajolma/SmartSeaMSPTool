package SmartSea::Schema::Result::Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

__PACKAGE__->table('tool.pressures');
__PACKAGE__->add_columns(qw/ id order title category /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'pressure');
__PACKAGE__->many_to_many(activities => 'activity2pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

sub list_impacts {
    my ($ap) = @_;
    my @impacts;
    for my $impact (sort {$b->strength*10+$b->belief <=> $a->strength*10+$a->belief} $ap->impacts) {
        my $ec = $impact->ecosystem_component;
        my $c = $ec->title;
        my $strength = $strength{$impact->strength};
        my $belief = $belief{$impact->belief};
        push @impacts, "impact on $c is $strength, $belief.";
    }
    return \@impacts;
}

sub HTML_list {
    my (undef, $objs, %arg) = @_;
    my ($uri, $edit, $context) = ($arg{uri}, $arg{edit}, $arg{context});
    my %data;
    my %li;
    for my $pre (@$objs) {
        my $p = $pre->title;
        my $ap = $pre->activity2pressure->single({activity => $context->id});
        
        my $t = [[b => $p],[1 => ", range of impact is ".$range{$ap->range}]];
        $li{pre}{$p} = item($t, $pre->id, %arg, ref => 'this pressure');
        
        $li{$p} = list_impacts($ap);

    }
    my @li;
    for my $pressure (sort keys %{$li{pre}}) {
        my @l;
        for my $impact (@{$li{$pressure}}) {
            push @l, [li => $impact];
        }
        my @item = @{$li{pre}{$pressure}};
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }
    push @li, [li => a(link => 'add pressure', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $oids, %arg) = @_;
    my @l = ([li => 'Pressure']);
    for my $a (qw/id title category/) {
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
    my $ap = $self->activity2pressure->single({activity => $arg{context}->id});
    my $impacts = list_impacts($ap);
    if (@$impacts) {
        my @l;
        for my $impact (@$impacts) {
            push @l, [li => $impact];
        }
        push @div, [p => "Range of impact is ".$range{$ap->range}.'.'], [ul => \@l];
    }
    return [div => $attributes, @div];
}

1;
