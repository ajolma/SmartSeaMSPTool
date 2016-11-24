package SmartSea::Schema::Result::Use;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.uses');
__PACKAGE__->add_columns(qw/ id title current_allocation /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'use');
__PACKAGE__->many_to_many(plans => 'plan2use', 'plan');
__PACKAGE__->has_many(use2layer => 'SmartSea::Schema::Result::Use2Layer', 'use');
__PACKAGE__->many_to_many(layers => 'use2layer', 'layer');
__PACKAGE__->has_many(use2activity => 'SmartSea::Schema::Result::Use2Activity', 'use');
__PACKAGE__->many_to_many(activities => 'use2activity', 'activity');
__PACKAGE__->belongs_to(current_allocation => 'SmartSea::Schema::Result::Dataset');

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    my %li;
    for my $use (@$objs) {
        my $p = $use->title;
        $li{use}{$p} = item([b => $p], $uri.'/'.$use->id, $edit, $use->id, 'this use');
        my @refs = $use->use2activity;
        for my $ref (@refs) {
            my $activity = $ref->activity;
            my $u = $activity->title;
            $data{$p}{$u} = 1;
            my $id = $use->id.'/'.$activity->id;
            $li{$p}{$u} = item($u, $uri.'/'.$id, $edit, $id, 'this activity from this use');
        }
    }
    my @body;
    for my $use (sort keys %{$li{use}}) {
        push @body, [p => $li{use}{$use}];
        my @a = sort keys %{$data{$use}};
        next unless @a;
        my @l;
        for my $activity (@a) {
            push @l, [li => $li{$use}{$activity}];
        }
        push @body, [ul => \@l];
    }
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, a(link => 'add use', url => $uri.'/new');
    }
    return \@body;
}

sub HTML_text {
    my ($self, $config, $oids) = @_;
    my @l;
    for my $a (qw/id title current_allocation/) {
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
    if (@$oids) {
        my $oid = shift @$oids;
        my $a = $self->activities->single({'activity.id' => $oid})->HTML_text($config, $oids);
        $ret = [$ret, @$a];
    } else {
        my $class = 'SmartSea::Schema::Result::Activity';
        my $l = $class->HTML_list([$self->activities], $config->{uri}, $config->{edit});
        $ret = [$ret, @$l];
    }
    return $ret;
}

1;
