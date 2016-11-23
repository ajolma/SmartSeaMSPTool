package SmartSea::Schema::Result::Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.pressures');
__PACKAGE__->add_columns(qw/ id order title category /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'pressure');
__PACKAGE__->many_to_many(activities => 'activity2pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

my %range = (1 => 'local', 2 => '< 500 m', 3 => '< 1 km', 4 => '< 10 km', 5 => '< 20 km', 6 => '> 20 km');

my %strength = (0 => 'nil', 1 => 'very weak', 2 => 'weak', 3 => 'strong', 4 => 'very strong');
my %belief = (1 => 'but this is very uncertain', 2 => 'but this is uncertain', 3 => 'and this is certain');

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
    my (undef, $objs, $uri, $edit, $context) = @_;
    my %data;
    my %li;
    for my $pre (@$objs) {
        my $p = $pre->title;
        my $ap = $pre->activity2pressure->single({activity => $context->id});
        
        my $t = [[b => $p],[1 => ", range of impact is ".$range{$ap->range}]];
        $li{pre}{$p} = SmartSea::HTML->item($t, $uri.'/'.$pre->id, $edit, $pre->id, 'this pressure');
        
        $li{$p} = list_impacts($ap);

    }
    my @body;
    for my $pressure (sort keys %{$li{pre}}) {
        push @body, [p => $li{pre}{$pressure}];
        next unless @{$li{$pressure}};
        my @l;
        for my $impact (@{$li{$pressure}}) {
            push @l, [li => $impact];
        }
        push @body, [ul => \@l];
    }
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, SmartSea::HTML->a(link => 'add pressure', url => $uri.'/new');
    }
    return \@body;
}

sub HTML_text {
    my ($self, $config, $oids, $context) = @_;
    my @l;
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
    my $ret = [ul => \@l];
    my $ap = $self->activity2pressure->single({activity => $context->id});
    my $impacts = list_impacts($ap);
    if (@$impacts) {
        my @l;
        for my $impact (@$impacts) {
            push @l, [li => $impact];
        }
        return [$ret, [p => "Range of impact is ".$range{$ap->range}.'.'], [ul => \@l]];
    } else {
        return [$ret];
    }
}

1;
