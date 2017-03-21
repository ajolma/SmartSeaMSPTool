package SmartSea::Schema::Result::ColorScale;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('color_scales');
__PACKAGE__->add_columns(qw/ id name /);
__PACKAGE__->set_primary_key('id');

sub HTML_list {
    my (undef, $objs, %args) = @_;
    # plan -> use -> layer -> style -> color_scale
    # dataset -> style -> color_scale
    my @li = ();
    my $ret = [ul => \@li];
    return [ li => [0 => 'ColorScales:'], $ret ] if $args{named_item};
    return $ret;
}

sub li {
    my ($self) = @_;
    return [li=>[[b=>'Color scale: '],[0=>$self->name]]];
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    return [li => [[b => "color scale"],[1 => " = ".$self->name]]];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;
    return [ 0 => '' ];
}

1;
