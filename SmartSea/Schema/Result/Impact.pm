package SmartSea::Schema::Result::Impact;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my %attributes = (
    activity2pressure   => { i => 1, input => 'lookup', class => 'Activity2Pressure' },
    ecosystem_component => { i => 2, input => 'lookup', class => 'EcosystemComponent' },
    strength            => { i => 3, input => 'text', size => 10 },
    belief              => { i => 4, input => 'text', size => 10 },
    );

__PACKAGE__->table('impacts');
__PACKAGE__->add_columns(qw/ id activity2pressure ecosystem_component strength belief /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure');
__PACKAGE__->belongs_to(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent');

sub attributes {
    return \%attributes;
}

sub relationship_methods {
    my $self = shift;
    return { };
}

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my $self = shift;
    return 'to '.$self->ecosystem_component->name;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my ($uri, $edit) = ($args{uri}, $args{edit});
    my %data;
    for my $impact (@$objs) {
        my $t = $impact->activity2pressure->name;
        my $li = item($t, $impact->id, %args, ref => 'this impact');
        $data{$impact->ecosystem_component->name}{$t} = [li => $li];
    }
    my @li;
    for my $component (sort keys %data) {
        my @ul;
        for my $ul (sort keys %{$data{$component}}) {
            push @ul, $data{$component}{$ul};
        }
        push @li, [li => [[b => $component], [ul => \@ul]]];
    }
    push @li, [li => a(link => 'add', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l = ([li => 'Impact']);
    for my $a (qw/id activity2pressure ecosystem_component strength belief/) {
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
    return [div => $attributes, [ul => \@l]];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    my @form;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Impact')) {
        for my $key (qw/activity2pressure ecosystem_component strength belief/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $activity2pressure = drop_down(name => 'activity2pressure', 
                                      objs => [$args{schema}->resultset('Activity2Pressure')->all], 
                                      selected => $values->{activity2pressure});
    my $ecosystem_component = drop_down(name => 'ecosystem_component', 
                                        objs => [$args{schema}->resultset('EcosystemComponent')->all], 
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

    push @form, (
        [ p => [[1 => 'Ecosystem component: '],$ecosystem_component] ],
        [ p => [[1 => 'Activity+Pressure: '],$activity2pressure] ],
        [ p => [[1 => 'Strength: '],$strength] ],
        [ p => [[1 => 'Belief: '],$belief] ],
        button(value => "Store")
    );
    return [form => $attributes, @form];
}

1;
