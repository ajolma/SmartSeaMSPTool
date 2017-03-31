package SmartSea::Schema::Result::PressureClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

my %attributes = (
    name     => { i => 1,  input => 'text',  size => 20 },
    ordr     => { i => 2,  input => 'text',  size => 10 },
    category => { i => 3,  input => 'lookup', class => 'PressureCategory' },
    );

__PACKAGE__->table('pressure_classes');
__PACKAGE__->add_columns(qw/ id ordr name category /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'pressure_class');
__PACKAGE__->many_to_many(activities => 'activity2pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

sub attributes {
    return \%attributes;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    push @l, [li => 'Activity'] unless $args{activity};
    for my $a (qw/id name category/) {
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
    if ($args{activity}) {
        my $ap = $self->activity2pressure->single({activity => $args{activity}});
        my $impacts = $ap->impacts_list;
        push @l, [li => [0 => "Range of impact is ".$range{$ap->range}.'.'], [ul => $impacts]] if @$impacts;
    } else {
        my %a;
        my %ec;
        for my $ap ($self->activity2pressure->all) {
            my $a = $ap->activity->id;
            $a{$ap->activity->name} = $a;
            for my $i ($ap->impacts) {
                next if $i->strength == 0;
                my $t = $i->ecosystem_component->name;
                $ec{$t}{$a} = 1;
            }
        }
        my @li;
        my %ati;
        my $i = 0;
        for my $a (sort keys %a) {
            push @li, [li => $a];
            $ati{$a{$a}} = ++$i;
        }
        push @l, [li => [0 => 'Caused by activities'], [ol => [@li]]];
        @li = ();
        for my $t (sort keys %ec) {
            my %a;
            for my $a (keys %{$ec{$t}}) {
                $a{$ati{$a}} = 1;
            }
            my @a = sort keys %a;
            push @li, [li => $t." (Activities: @a)"];
        }
        push @l, [li => [0 => 'Impacts ecosystem components'], [ul => [@li]]];
    }
    my $ret = [ul => \@l];
    return [ li => [0 => 'Pressure:'], $ret ] if $args{named_item};
    return $ret;
}

1;
