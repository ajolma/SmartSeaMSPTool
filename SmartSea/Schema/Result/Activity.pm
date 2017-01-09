package SmartSea::Schema::Result::Activity;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.activities');
__PACKAGE__->add_columns(qw/ id order title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(activity2pressure => 'SmartSea::Schema::Result::Activity2Pressure', 'activity');
__PACKAGE__->many_to_many(pressures => 'activity2pressure', 'pressure');
__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    my %li;
    for my $act (@$objs) {
        my $a = $act->title;
        $li{act}{$a} = item([b => $a], $act->id, $uri, $edit, 'this activity');
        my @refs = $act->activity2pressure;
        for my $ref (@refs) {
            my $pressure = $ref->pressure;
            my $p = $pressure->title;
            $data{$a}{$p} = 1;
            my $id = $act->id.'/'.$pressure->id;
            $li{$a}{$p} = item($p, $id, $uri, $edit, 'this pressure from this activity');
        }
    }
    my @li;
    for my $act (sort keys %{$li{act}}) {
        push @li, [li => $li{act}{$act}];
        my @p = sort keys %{$data{$act}};
        next unless @p;
        my @l;
        for my $pressure (@p) {
            push @l, [li => $li{$act}{$pressure}];
        }
        push @li, [ul => \@l];
    }
    push @li, [li => a(link => 'add activity', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, $config, $oids) = @_;
    my @l = ([li => 'Activity']);
    for my $a (qw/id title/) {
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
    if (@$oids) {
        my $oid = shift @$oids;
        push @div, $self->pressures->single({'pressure.id' => $oid})->HTML_div({}, $config, $oids, $self);
    } else {
        my $class = 'SmartSea::Schema::Result::Pressure';
        push @div, $class->HTML_list([$self->pressures], $config->{uri}, $config->{edit}, $self);
    }
    return [div => $attributes, @div];
}

1;
