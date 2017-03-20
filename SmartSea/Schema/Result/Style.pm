package SmartSea::Schema::Result::Style;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core;
use SmartSea::HTML qw(:all);

my %attributes = (
    color_scale => { i => 1, input => 'lookup', class => 'ColorScale', allow_null => 0 },
    min =>         { i => 3, input => 'text', size => 20, empty_is_null => 1 },
    max =>         { i => 4, input => 'text', size => 20, empty_is_null => 1 },
    classes =>     { i => 5, input => 'text', size => 20, empty_is_null => 1 },
    scales =>      { i => 6, input => 'text', size => 20 }
    );

__PACKAGE__->table('styles');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(color_scale => 'SmartSea::Schema::Result::ColorScale');

sub attributes {
    return \%attributes;
}

sub name {
    my $self = shift;
    my $name = '';
    $name .= $self->color_scale->name if $self->color_scale;
    $name .= ' ['.$self->min.'..'.$self->max.']' if defined $self->min && defined $self->max;
    $name .= ' '.$self->classes.' classes' if defined $self->classes;
    return $name;
}

sub get_object {
    my ($class, %args) = @_;
    my $oid = shift @{$args{oids}};
    my $obj;
    $oid =~ s/^\w+://;
    eval {
        $obj = $args{schema}->resultset('Style')->single({id => $oid});
    };
    say STDERR "Error: $@" if $@;
    return $obj;
}

sub HTML_list {
    my (undef, $objs, %args) = @_;
    # plan -> use -> layer -> style
    # dataset -> style
    my @li = ();
    my $ret = [ul => \@li];
    return [ li => [0 => 'ColorScales:'], $ret ] if $args{named_item};
    return $ret;
}

sub li {
    my ($self) = @_;
    my @l;
    push @l, $self->color_scale->li if defined $self->color_scale;
    push @l, [li => [[b => "minimum"],[1 => " = ".$self->min]]] if defined $self->min;
    push @l, [li => [[b => "maximum"],[1 => " = ".$self->max]]] if defined $self->max;
    push @l, [li => [[b => "classes"],[1 => " = ".$self->classes]]] if defined $self->classes;
    push @l, [li => [[b => "scales"],[1 => " = ".$self->scales]]] if defined $self->scales;
    return [ li => [[b=>'Style:'],[ul => \@l]] ];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    my @l;
    push @l, $self->color_scale->HTML_div if defined $self->color_scale;
    push @l, [li => [[b => "minimum"],[1 => " = ".$self->min]]] if defined $self->min;
    push @l, [li => [[b => "maximum"],[1 => " = ".$self->max]]] if defined $self->max;
    push @l, [li => [[b => "classes"],[1 => " = ".$self->classes]]] if defined $self->classes;
    push @l, [li => [[b => "scales"],[1 => " = ".$self->scales]]] if defined $self->scales;
    return [ ul => \@l ];
}

sub inputs {
    my ($self, $values, $schema) = @_;
    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Style')) {
        for my $key (keys %attributes) {
            next unless defined $self->$key;
            next if defined $values->{$key};
            $values->{$key} = $self->$key;
        }
    }
    return widgets(\%attributes, $values, $schema);
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;
    return [ 0 => '' ];
}

1;
