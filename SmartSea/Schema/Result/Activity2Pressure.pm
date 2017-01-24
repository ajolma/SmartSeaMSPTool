package SmartSea::Schema::Result::Activity2Pressure;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.activity2pressure');
__PACKAGE__->add_columns(qw/ id activity pressure range /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(activity => 'SmartSea::Schema::Result::Activity');
__PACKAGE__->belongs_to(pressure => 'SmartSea::Schema::Result::Pressure');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'activity2pressure');

sub as_text {
    my ($self) = @_;
    return $self->activity->title . ' - ' . $self->pressure->title;
}
*title = *as_text;

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my ($uri, $edit) = ($args{uri}, $args{edit});
    my %data;
    for my $link (@$objs) {
        my $li = item($link->pressure->title, $link->id, %args, ref => 'this link');
        push @{$data{$link->activity->title}}, [li => $li];
    }
    my @li;
    for my $activity (sort keys %data) {
        push @li, [li => [[b => $activity], [ul => \@{$data{$activity}}]]];
    }
    push @li, [li => a(link => 'add', url => $uri.'/new')] if $edit;
    return [ul => \@li];
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
