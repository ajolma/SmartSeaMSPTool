package SmartSea::Schema::Result::EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

__PACKAGE__->table('tool.ecosystem_components');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'ecosystem_component');

sub order {
    my $self = shift;
    return $self->id;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    my ($uri, $edit) = ($args{uri}, $args{edit});
    my %li;
    for my $ec (@$objs) {
        my $c = $ec->title;
        $li{ec}{$c} = item([b => $c], $ec->id, %args, ref => 'this component');
        my @impacts = $ec->impacts;
        for my $impact (@impacts) {
            next unless defined $impact->strength;
            next unless defined $impact->belief;
            my $activity = $impact->activity2pressure->activity;
            my $i = $activity->title;
            if (exists $li{$c}{$i}) {
                push @{$li{$c}{$i}}, [$impact->strength,$impact->belief];
            } else {
                $li{$c}{$i} = [[$impact->strength,$impact->belief]];
            }
            #my $id = $ec->id.'/'.$activity->id;
            #$li{$c}{$i} = item($i, $id, %args, ref => 'this activity from this component');
        }
    }
    my @li;
    for my $c (sort keys %{$li{ec}}) {
        my @i = sort keys %{$li{$c}};
        if (@i) {
            my @li2;
            my %e;
            for my $i (@i) {
                my $sb = $li{$c}{$i};
                my $pdf = impact_pdf(@{$sb->[0]});
                if (@$sb > 1) {
                    for my $x (1..@$sb-1) {
                        $pdf = impact_sum($pdf, @{$sb->[$x]});
                    }
                }
                $e{$i} = impact_expected_value($pdf);
            }
            for my $li (sort {$e{$b} <=> $e{$a}} keys %e) {
                push @li2, [li => $li." $e{$li}"];
            }
            push @li, [li => [@{$li{ec}{$c}},[ul => \@li2]]];
        } else {
            push @li, [li => $li{ec}{$c}];
        }
    }
    push @li, [li => a(link => 'add use', url => $uri.'/new')] if $edit;
    return [ul => \@li];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l = ([li => 'Ecosystem component']);
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
    return [div => $attributes, [ul => \@l]];
}

1;
