package SmartSea::HTML;
use strict;
use warnings;
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
    return join '', @{$self->{cache}};
}
1;
