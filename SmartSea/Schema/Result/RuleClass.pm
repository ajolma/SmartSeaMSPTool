package SmartSea::Schema::Result::RuleClass;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('rule_classes');
__PACKAGE__->add_columns(qw/id name/);
__PACKAGE__->set_primary_key(qw/ id /);

sub HTML_list {
    my (undef, $objs, %args) = @_;
    # plan -> use -> layer -> rule
    my @li = ();
    my $ret = [ul => \@li];
    return [ li => [0 => 'Rules:'], $ret ] if $args{named_item};
    return $ret;
}

sub HTML_div {
    my ($self, $attributes, %args) = @_;
    return [ 0 => '' ];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;
    return [ 0 => '' ];
}

1;
