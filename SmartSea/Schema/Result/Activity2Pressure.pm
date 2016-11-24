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

sub HTML_form {
    my ($self, $config, $values) = @_;

    my @ret;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Activity2Pressure')) {
        for my $key (qw/activity pressure range/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @ret, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $activity = drop_down(name => 'activity', 
                             objs => [$config->{schema}->resultset('Activity')->all], 
                             selected => $values->{activity});
    my $pressure = drop_down(name => 'pressure', 
                             objs => [$config->{schema}->resultset('Pressure')->all], 
                             selected => $values->{pressure});

    my $range = text_input(
        name => 'range',
        size => 10,
        value => $values->{range} // ''
    );

    push @ret, (
        [ p => [[1 => 'Activity: '],$activity] ],
        [ p => [[1 => 'Pressure: '],$pressure] ],
        [ p => [[1 => 'Range: '],$range] ],
        [input => {type=>"submit", name=>'submit', value=>"Store"}]
    );
    return \@ret;
}

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    for my $link (@$objs) {
        my $li = [ a(link => $link->pressure->title, url => $uri.'/'.$link->id) ];
        if ($edit) {
            push @$li, (
                [1 => '  '],
                a(link => "edit", url => $uri.'/'.$link->id.'?edit'),
                [1 => '  '],
                [input => {type=>"submit", 
                           name=>$link->id, 
                           value=>"Delete",
                           onclick => "return confirm('Are you sure you want to delete this link?')" 
                 }
                ]
            )
        }
        push @{$data{$link->activity->title}}, [li => $li];
    }
    my @body;
    for my $activity (sort keys %data) {
        push @body, [b => $activity], [ul => \@{$data{$activity}}];
    }
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, a(link => 'add', url => $uri.'/new');
    }
    return \@body;
}

1;
