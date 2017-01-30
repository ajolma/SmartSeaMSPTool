package SmartSea::Schema::Result::Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

__PACKAGE__->table('tool.pressures');
__PACKAGE__->add_columns(qw/ id order title category /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'pressure');
__PACKAGE__->many_to_many(activities => 'activity2pressure', 'activity');
__PACKAGE__->belongs_to(category => 'SmartSea::Schema::Result::PressureCategory');

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    return SmartSea::Schema::Result::Use->get_object(%args) if @{$args{oids}};
    my $obj;
    eval {
        $obj = $args{schema}->resultset('Pressure')->single({id => $oid});
    };
    say STDERR "Error: $@" if $@;
    return $obj;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my %data;
    my %li;
    my %has;
    for my $p (@$objs) {
        my $t = $p->title;
        $has{$p->id} = 1;
        if ($args{activity}) {
            my $ap = $p->activity2pressure->single({activity => $args{activity}});
            my $e = [[b => $t],[1 => ", range of impact is ".$range{$ap->range}]];
            my $i = item($e, $p->id, %args, ref => 'this activity-pressure link');
            $li{$t} = [li => $i, [ul => $ap->impacts_list]];
        } else {
            $li{$t} = [li => item($t, $p->id, %args, ref => 'this pressure')];
        }
    }

    my @li;
    for my $pressure (sort keys %li) {
        push @li, $li{$pressure};
    }

    if ($args{edit} && $args{activity} && !$args{use}) {
        my @objs;
        for my $obj ($args{schema}->resultset('Pressure')->all) {
            next if $has{$obj->id};
            push @objs, $obj;
        }
        if (@objs) {
            my $drop_down = drop_down(name => 'pressure', objs => \@objs);
            push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'pressure')]];
        }
    }
    
    my $ret = [ul => \@li];
    return [ li => [ [0 => 'Pressures:'], $ret ]] if $args{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    push @l, [li => 'Activity'] unless $args{activity};
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
    if ($args{activity}) {
        my $ap = $self->activity2pressure->single({activity => $args{activity}});
        my $impacts = $ap->impacts_list;
        push @l, [li => [0 => "Range of impact is ".$range{$ap->range}.'.'], [ul => $impacts]] if @$impacts;
    } else {
        my %a;
        my %ec;
        for my $ap ($self->activity2pressure->all) {
            my $a = $ap->activity->id;
            $a{$ap->activity->title} = $a;
            for my $i ($ap->impacts) {
                next if $i->strength == 0;
                my $t = $i->ecosystem_component->title;
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

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Pressure')) {
        for my $key (qw/title category/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $title = text_input(
        name => 'title',
        size => 10,
        value => $values->{title} // ''
    );

    my $category = drop_down(name => 'category', 
                             objs => [$args{schema}->resultset('PressureCategory')->all], 
                             selected => $values->{category});

    push @form, (
        [ p => [[1 => 'Title: '],$title] ],
        [ p => [[1 => 'Category: '],$category] ],
        button(value => "Store")
    );
    return [form => $attributes, @form];
}

1;
