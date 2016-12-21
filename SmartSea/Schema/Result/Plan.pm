package SmartSea::Schema::Result::Plan;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.plans');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(plan2use => 'SmartSea::Schema::Result::Plan2Use', 'plan');
__PACKAGE__->many_to_many(uses => 'plan2use', 'use');

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my %data;
    my %li;
    for my $plan (@$objs) {
        my $p = $plan->title;
        $li{plan}{$p} = item([b => $p], $plan->id, $uri, $edit, 'this plan');
        for my $use ($plan->uses) {
            my $u = $use->title;
            $data{$p}{$u} = 1;
            my $id = $plan->id.'/'.$use->id;
            $li{$p}{$u} = item($u, $id, $uri, $edit, 'this use from this plan');
        }
    }
    my @body = ([h2 => 'Plans']);
    for my $plan (sort keys %{$li{plan}}) {
        push @body, @{$li{plan}{$plan}};
        my @u = sort keys %{$data{$plan}};
        next unless @u;
        my @l;
        for my $use (@u) {
            push @l, [li => $li{$plan}{$use}];
        }
        push @body, [ul => \@l];
    }
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, a(link => 'add plan', url => $uri.'/new');
    }
    return \@body;
}

sub HTML_text {
    my ($self, $config, $oids) = @_;
    my @l = ([li => 'Plan']);
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
    my $ret = [ul => \@l];
    if (@$oids) {
        my $oid = shift @$oids;
        my $use = $self->uses->single({'use.id' => $oid})->HTML_text($config, $oids);
        return [$ret, $use] if @$use;
    } else {
        my $class = 'SmartSea::Schema::Result::Use';
        my $l = $class->HTML_list([$self->uses], $config->{uri}, $config->{edit});
        return [$ret, $l] if @$l;
    }
    return $ret;
}

sub HTML_form {
    my ($self, $config, $values) = @_;

    my @ret;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Plan')) {
        for my $key (qw/title/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @ret, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $title = text_input(
        name => 'title',
        size => 15,
        value => $values->{title} // ''
    );

    push @ret, (
        [ p => [[1 => 'title: '],$title] ],
        button(value => "Store")
    );

    return \@ret;
}

1;
