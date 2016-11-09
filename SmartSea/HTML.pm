package SmartSea::HTML;
use strict;
use warnings;
use HTML::Entities;
use Geo::OGC::Service;
our @ISA = qw(Geo::OGC::Service::XMLWriter);
sub new {
    my $class = shift;
    my $self = bless {}, 'SmartSea::HTML';
    $self->element(@_) if @_;
    return $self;
}
sub write {
    my $self = shift;
    my $line = shift;
    push @{$self->{cache}}, $line;
}
sub html {
    my $self = shift;
    $self->element(@_) if @_;
    return join '', @{$self->{cache}};
}
sub a {
    my (undef, %arg) = @_;
    return [a => encode_entities($arg{link}), {href=>$arg{url}}];
}
sub select {
    my (undef, %arg) = @_;
    my @options;
    for my $value (@{$arg{values}}) {
        my $attr = {value => $value};
        $attr->{selected} = 'selected' if $value eq $arg{selected};
        push @options, [option => $attr, encode_entities($arg{visuals}->{$value})];
    }
    return [select => {name => $arg{name}}, \@options];
}
sub checkbox {
    my (undef, %arg) = @_;
    my $attr = {type => 'checkbox',name => $arg{name},value => $arg{value}};
    $attr->{checked} = 'checked' if $arg{checked};
    return [input => $attr, encode_entities($arg{visual})];
}
sub text {
    my (undef, %arg) = @_;
    return [input => { type => 'text', 
                       name => $arg{name}, 
                       value => encode_entities($arg{visual}),
                       size => $arg{size} // 10,
            }
        ];
}
1;
