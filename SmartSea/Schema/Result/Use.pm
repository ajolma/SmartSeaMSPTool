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
    my %li;
    for my $use (@$objs) {
        my $u = $use->title;
        $li{$u}{0} = item([b => $u], $use->id, $uri, $edit, 'this use');
        for my $activity ($use->activities) {
            my $a = $activity->title;
            my $id = $use->id.'/'.$activity->id;
            $li{$u}{$a} = item($a, $id, $uri, $edit, 'this activity from this use');
        }
    }
    my @body;
    for my $use (sort keys %li) {
        push @body, [p => $li{$use}{0}];
        my @a = sort keys %{$li{$use}};
        next unless @a > 1;
        my @l;
        for my $activity (@a) {
            next unless $activity;
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
    my @l = ([li => 'Use']);
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
    my $ret = [[ul => \@l]];
    if (@$oids) {
        my $oid = shift @$oids;
        my $a = $self->activities->single({'activity.id' => $oid})->HTML_text($config, $oids);
        push @$ret, @$a if @$a;
    } else {
        my $class = 'SmartSea::Schema::Result::Activity';
        my $l = $class->HTML_list([$self->activities], $config->{uri}, $config->{edit});
        push @$ret, @$l if @$l;
    }
    return $ret;
}

1;
