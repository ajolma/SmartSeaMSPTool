package SmartSea::HTML;
use strict;
use warnings;
use Carp;
use HTML::Entities qw/encode_entities_numeric/;
use Scalar::Util 'blessed';
use Geo::OGC::Service;
use SmartSea::Core qw/:all/;

require Exporter;

our @ISA = qw(Exporter Geo::OGC::Service::XMLWriter);
our @EXPORT_OK = qw(a button checkbox text_input textarea drop_down hidden);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

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
    my (%arg) = @_;
    return [a => {href=>$arg{url}}, encode_entities_numeric($arg{link})];
}
sub button {
    my (%arg) = @_;
    $arg{name} //= 'submit';
    my %attr = (type=>"submit", name=>$arg{name}, value=>$arg{value});
    $attr{onclick} = $arg{onclick} if $arg{onclick};
    return [input => \%attr]
}
sub checkbox {
    my (%arg) = @_;
    my $attr = {type => 'checkbox', name => $arg{name}, value => $arg{value}};
    $attr->{id} = $arg{id} if $arg{id};
    $attr->{checked} = 'checked' if $arg{checked};
    return [input => $attr, encode_entities_numeric($arg{visual})];
}
sub text_input {
    my (%arg) = @_;
    return [input => { type => 'text', 
                       name => $arg{name},
                       value => encode_entities_numeric($arg{value}),
                       size => $arg{size} // 10,
            }
        ];
}
sub textarea {
    my (%arg) = @_;
    return [
        textarea => {
            name => $arg{name},
            rows => ($arg{rows} // 4),
            cols => ($arg{cols} // 50),
        }, $arg{value} // ''
    ];
}
sub drop_down {
    my (%arg) = @_;
    warn_unknowns(\%arg, qw/name values visuals selected not_null objs/);
    my $name = $arg{name} // '';
    my $values = $arg{values};
    my $visuals = $arg{visuals} // {};
    my $selected = $arg{selected} // (!$arg{not_null} ? '' : 'NULL');
    $visuals->{NULL} = '' unless $arg{not_null};
    if ($arg{objs}) {
        my %objs;
        $values = [];
        for my $obj (@{$arg{objs}}) {
            my $id = blessed($obj) ? $obj->id : $obj->{id};
            my $name = blessed($obj) ? $obj->name : $obj->{name};
            $objs{$id} = $name;
            $visuals->{$id} = $name;
            push @$values, $id;
        }
        #$values //= [sort {$objs{$a} cmp $objs{$b}} keys %objs];
        unshift @$values, 'NULL' unless $arg{not_null};
    }
    my @options;
    for my $value (@$values) {
        my $attr = {value => $value};
        $attr->{selected} = 'selected' if $value eq $selected;
        push @options, [option => $attr, encode_entities_numeric($visuals->{$value})];
    }
    return [select => {name => $name}, \@options];
}
sub hidden {
    my ($name, $value) = @_;
    return [input => {type => 'hidden', name => $name, value => $value}];
}
sub spinner {
    my (%arg) = @_;
    $arg{step} //= 1;
    return [input => {name => $arg{name},
                      type => 'number', 
                      min => $arg{min}, 
                      max => $arg{max}, 
                      step => $arg{step}, 
                      value => $arg{value}}];
}
1;
