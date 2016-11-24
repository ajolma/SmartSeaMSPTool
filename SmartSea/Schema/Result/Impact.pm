package SmartSea::Schema::Result::Impact;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.impacts');
__PACKAGE__->add_columns(qw/ id activity2pressure ecosystem_component strength belief /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');

sub HTML_text {
    my ($self) = @_;
    my @l;
    for my $a (qw/id activity2pressure ecosystem_component strength belief/) {
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
    return [ul => \@l];
}

sub HTML_form {
    my ($self, $config, $values) = @_;

    my @ret;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Impact')) {
        for my $key (qw/activity2pressure ecosystem_component strength belief/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @ret, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $activity2pressure = drop_down(name => 'activity2pressure', 
                                      objs => [$config->{schema}->resultset('Activity2Pressure')->all], 
                                      selected => $values->{activity2pressure});
    my $ecosystem_component = drop_down(name => 'ecosystem_component', 
                                        obj => [$config->{schema}->resultset('EcosystemComponent')->all], 
                                        selected => $values->{ecosystem_component});
    
    my $strength = text_input(
        name => 'strength',
        size => 10,
        value => $values->{strength} // ''
    );
    my $belief = text_input(
        name => 'belief',
        size => 10,
        value => $values->{belief} // ''
    );

    push @ret, (
        [ p => [[1 => 'Ecosystem component: '],$ecosystem_component] ],
        [ p => [[1 => 'Activity+Pressure: '],$activity2pressure] ],
        [ p => [[1 => 'Strength: '],$strength] ],
        [ p => [[1 => 'Belief: '],$belief] ],
        [input => {type=>"submit", name=>'submit', value=>"Store"}]
    );
    return \@ret;
}

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    for my $impact (@$objs) {
        my $t = $impact->activity2pressure->title;
        my $li = [ a(link => $t, url => $uri.'/'.$impact->id) ];
        if ($edit) {
            push @$li, (
                [1 => '  '],
                a(link => "edit", url => $uri.'/'.$impact->id.'?edit'),
                [1 => '  '],
                [input => {type=>"submit", 
                           name=>$impact->id, 
                           value=>"Delete",
                           onclick => "return confirm('Are you sure you want to delete this impact?')" 
                 }
                ]
            )
        }
        $data{$impact->ecosystem_component->title}{$t} = [li => $li];
    }
    my @body;
    for my $component (sort keys %data) {
        my @ul;
        for my $ul (sort keys %{$data{$component}}) {
            push @ul, $data{$component}{$ul};
        }
        push @body, [b => $component], [ul => \@ul];
    }
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, a(link => 'add', url => $uri.'/new');
    }
    return \@body;
}

1;
