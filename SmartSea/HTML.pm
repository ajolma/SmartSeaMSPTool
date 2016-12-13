package SmartSea::HTML;
use strict;
use warnings;
use HTML::Entities;
use Geo::OGC::Service;
require Exporter;
our @ISA = qw(Exporter Geo::OGC::Service::XMLWriter);
our @EXPORT_OK = qw(a button checkbox text_input textarea drop_down item widgets);
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
sub button {
    my (%arg) = @_;
    $arg{name} //= 'submit';
    return [input => {type=>"submit", name=>$arg{name}, value=>$arg{value}}]
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
    my ($title, $id, $url, $edit, $ref) = @_;
    $url .= '/'.$id;
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
sub widgets {
    my ($attributes, $values, $schema) = @_;
    my %widgets;
    for my $key (keys %$attributes) {
        my $a = $attributes->{$key};
        if ($a->{type} eq 'text') {
            $widgets{$key} = text_input(
                name => $key,
                size => ($a->{size} // 10),
                value => $values->{$key} // ''
            );
        } elsif ($a->{type} eq 'textarea') {
            $widgets{$key} = textarea(
                name => $key,
                rows => $a->{rows},
                cols => $a->{cols},
                value => $values->{$key} // ''
            );
        } elsif ($a->{type} eq 'lookup') {
            my $objs;
            if ($a->{objs}) {
                $objs = [$schema->resultset($a->{class})->search($a->{objs})];
            } else {
                $objs = [$schema->resultset($a->{class})->all];
            }
            $widgets{$key} = drop_down(
                name => $key,
                objs => $objs,
                selected => $values->{$key},
                allow_null => $a->{allow_null}
            );
        } elsif ($a->{type} eq 'checkbox') {
            $widgets{$key} = checkbox(
                name => $key,
                visual => $a->{cue},
                checked => $values->{$key}
            );
        }
    }
    return \%widgets;
}
1;
