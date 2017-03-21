package SmartSea::Schema::Result::Activity2Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

__PACKAGE__->table('activity2pressure');
__PACKAGE__->add_columns(qw/ id activity pressure range /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');
__PACKAGE__->belongs_to(pressure => 'SmartSea::Schema::Result::Pressure');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'activity2pressure');

sub impacts_list {
    my ($self) = @_;
    my @impacts;
    for my $impact (sort {$b->strength*10+$b->belief <=> $a->strength*10+$a->belief} $self->impacts) {
        my $ec = $impact->ecosystem_component;
        my $c = $ec->name;
        my $strength = $strength{$impact->strength};
        my $belief = $belief{$impact->belief};
        push @impacts, [li => "impact on $c is $strength, $belief."];
    }
    return \@impacts;
}

sub as_text {
    my ($self) = @_;
    return $self->activity->name . ' - ' . $self->pressure->name;
}
*name = *as_text;

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my ($uri, $edit) = ($args{uri}, $args{edit});
    my %data;
    for my $link (@$objs) {
        my $li = item($link->pressure->name, $link->id, %args, ref => 'this link');
        push @{$data{$link->activity->name}}, [li => $li];
    }
    my @li;
    for my $activity (sort keys %data) {
        push @li, [li => [[b => $activity], [ul => \@{$data{$activity}}]]];
    }
    push @li, [li => a(link => 'add', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    push @l, [li => 'Activity to pressure link'] unless $args{use};
    for my $a (qw/id activity pressure range/) {
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
    $args{activity2pressure} = $self->id;
    if (my $oid = shift @{$args{oids}}) {
        my ($subclass) = $oid =~ s/^(\w+)://;
        $oid =~ s/^\w+://;
        push @l, $self->pressures->single({'pressure.id' => $oid})->HTML_div({}, %args, named_item => 1) 
            if $subclass eq 'pressure';
        push @l, $self->activities->single({'activity.id' => $oid})->HTML_div({}, %args, named_item => 1) 
            if $subclass eq 'activity';
    } else {
        $args{action} = $args{use} ? 'None' : 'Remove';
        push @l, SmartSea::Schema::Result::Pressure->HTML_list([$self->pressures], %args, named_item => 1);
        push @l, SmartSea::Schema::Result::Activity->HTML_list([$self->activities], %args, named_item => 1);
    }
    my $ret = [ul => \@l];
    return [ li => [0 => 'Activity to pressure link:'], $ret ] if $args{named_item};
    return [ div => $attributes, $ret ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Activity2Pressure')) {
        for my $key (qw/activity pressure range/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $activity = drop_down(name => 'activity', 
                             objs => [$args{schema}->resultset('Activity')->all], 
                             selected => $values->{activity});
    my $pressure = drop_down(name => 'pressure', 
                             objs => [$args{schema}->resultset('Pressure')->all], 
                             selected => $values->{pressure});

    my $range = text_input(
        name => 'range',
        size => 10,
        value => $values->{range} // ''
    );

    push @form, (
        [ p => [[1 => 'Activity: '],$activity] ],
        [ p => [[1 => 'Pressure: '],$pressure] ],
        [ p => [[1 => 'Range: '],$range] ],
        button(value => "Store")
    );
    return [form => $attributes, @form];
}

1;
