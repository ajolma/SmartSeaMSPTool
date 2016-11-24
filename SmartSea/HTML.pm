package SmartSea::HTML;
use strict;
use warnings;
use HTML::Entities;
use Geo::OGC::Service;
require Exporter;
our @ISA = qw(Exporter Geo::OGC::Service::XMLWriter);
our @EXPORT_OK = qw(a checkbox text_input drop_down item);
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
    return [a => encode_entities($arg{link}), {href=>$arg{url}}];
}
sub checkbox {
    my (%arg) = @_;
    my $attr = {type => 'checkbox',name => $arg{name},value => $arg{value}};
    $attr->{checked} = 'checked' if $arg{checked};
    return [input => $attr, encode_entities($arg{visual})];
}
sub text_input {
    my (%arg) = @_;
    return [input => { type => 'text', 
                       name => $arg{name}, 
                       value => encode_entities($arg{value}),
                       size => $arg{size} // 10,
            }
        ];
}
sub drop_down {
    my (%arg) = @_;
    my $name = $arg{name} // '';
    my $values = $arg{values};
    my $visuals = $arg{visuals} // {};
    my $selected = $arg{selected} // ($arg{allow_null} ? 'NULL' : '');
    $visuals->{NULL} = '' if $arg{allow_null};
    if ($arg{objs}) {
        my %objs;
        for my $obj (@{$arg{objs}}) {
            $objs{$obj->id} = $obj->title;
            $visuals->{$obj->id} = $obj->title;
        }
        $values = [sort {$objs{$a} cmp $objs{$b}} keys %objs];
        unshift @$values, 'NULL' if $arg{allow_null};
    }
    my @options;
    for my $value (@$values) {
        my $attr = {value => $value};
        $attr->{selected} = 'selected' if $value eq $selected;
        push @options, [option => $attr, encode_entities($visuals->{$value})];
    }
    return [select => {name => $name}, \@options];
}
sub item {
    my ($title, $url, $edit, $id, $ref) = @_;
    my $i = [ a(link => $title, url => $url) ];
    if ($edit) {
        $url .= '?edit';
        push @$i, (
            [1 => '  '],
            a(link => "edit", url => $url),
            [1 => '  '],
            [input => {type=>"submit", 
                       name=>$id, 
                       value=>"Delete",
                       onclick => "return confirm('Are you sure you want to delete $ref?')" 
             }
            ]
        )
    }
    return $i;
}
1;
