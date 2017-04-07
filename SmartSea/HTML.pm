package SmartSea::HTML;
use strict;
use warnings;
use Carp;
use HTML::Entities;
use Scalar::Util 'blessed';
use Geo::OGC::Service;
use SmartSea::Core qw/:all/;

require Exporter;

our @ISA = qw(Exporter Geo::OGC::Service::XMLWriter);
our @EXPORT_OK = qw(a button checkbox text_input textarea drop_down hidden item widgets);
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
    return [a => {href=>$arg{url}}, encode_entities($arg{link})];
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
    warn_unknowns(\%arg, qw/name values visuals selected allow_null objs/);
    my $name = $arg{name} // '';
    my $values = $arg{values};
    my $visuals = $arg{visuals} // {};
    my $selected = $arg{selected} // ($arg{allow_null} ? 'NULL' : '');
    $visuals->{NULL} = '' if $arg{allow_null};
    if ($arg{objs}) {
        my %objs;
        for my $obj (@{$arg{objs}}) {
            my $id = blessed($obj) ? $obj->id : $obj->{id};
            my $name = blessed($obj) ? $obj->name : $obj->{name};
            $objs{$id} = $name;
            $visuals->{$id} = $name;
        }
        $values //= [sort {$objs{$a} cmp $objs{$b}} keys %objs];
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
sub item {
    my ($name, $id, %arg) = @_;
    return ref($name) ? [$name] : [[0 => $name]] unless $arg{uri};
    my $uri = $arg{uri}.'/'.$id;
    my @i = (a(link => $name, url => $uri));
    my $value = $arg{action} // 'Delete';
    return $i[0] if $arg{action} eq 'None';
    if ($arg{edit}) {
        #$url .= '?edit';
        push @i, ([1 => '  '], a(link => "edit", url => $uri."?edit")) if $value eq 'Delete';
        push @i, (
            [1 => '  '],
            [input => {
                type => "submit", 
                name => $id, 
                value => $value,
                onclick => "return confirm('Are you sure you want to ".lc($value)." $arg{ref}?')" 
             }]);
    }
    return \@i;
}
sub widgets {
    my ($attributes, $values, $schema) = @_;
    my @form;
    for my $key (sort {$attributes->{$a}{i} <=> $attributes->{$b}{i}} keys %$attributes) {
        my $a = $attributes->{$key};
        next if $a->{input} eq 'ignore';
        my $input;
        if ($a->{input} eq 'hidden') {
            if (exists $values->{$key}) {
                if (ref $values->{$key}) {
                    $input = hidden($key, $values->{$key}->id);
                } else {
                    $input = hidden($key, $values->{$key});
                }
            }
        } elsif ($a->{input} eq 'text') {
            $input = text_input(
                name => $key,
                size => ($a->{size} // 10),
                value => $values->{$key} // ''
            );
        } elsif ($a->{input} eq 'textarea') {
            $input = textarea(
                name => $key,
                rows => $a->{rows},
                cols => $a->{cols},
                value => $values->{$key} // ''
            );
        } elsif ($a->{input} eq 'lookup') {
            my $objs;
            if (ref $a->{objs} eq 'ARRAY') {
                $objs = $a->{objs};
            } elsif ($a->{objs}) {
                $objs = [$schema->resultset($a->{source})->search($a->{objs})];
            } else {
                $objs = [$schema->resultset($a->{source})->all];
            }
            my $id;
            if ($values->{$key}) {
                if (ref $values->{$key}) {
                    $id = $values->{$key}->id;
                } else {
                    $id = $values->{$key};
                }
            }
            $input = drop_down(
                name => $key,
                objs => $objs,
                selected => $id,
                values => $a->{values},
                allow_null => $a->{allow_null}
            );
        } elsif ($a->{input} eq 'checkbox') {
            $input = checkbox(
                name => $key,
                visual => $a->{cue},
                checked => $values->{$key}
            );
        } elsif ($a->{input} eq 'spinner') {
            $input = spinner(
                name => $key,
                min => $a->{min},
                max => $a->{max},
                value => $values->{$key} // 1
            );
        }
        if ($a->{input} eq 'object') {
            unless ($a->{required}) {
                push @form, [ p => checkbox(
                                  name => $key.'_is',
                                  visual => "Define ".$a->{source},
                                  checked => $values->{$key},
                                  id => 'style_cb' )
                ];
                my $code =<< 'END_CODE';
function dim(cb,id){
  document.getElementById(id).style.display=(cb.checked)?'':'none';
}
window.onload = function() {
  var cb = document.getElementById("style_cb");
  var id = "style";
  if (!cb.checked) dim(this,id);
  cb.addEventListener("change", function() {
    dim(this,id);
  }, false);
};
END_CODE
                push @form, [script => $code];
            } else {
                push @form, hidden($key.'_is', 1);
            }
            my @style;
            if ($values->{$key}) {
                @style = $values->{$key}->inputs($values, $schema);
            } else {
                my $class = 'SmartSea::Schema::Result::'.$a->{source};
                @style = $class->inputs($values, $schema);
            }
            push @form, [div => {id=>'style'}, @style];
        } else {
            if ($a->{input} eq 'hidden') {
                push @form, $input if defined $input;
            } else {
                push @form, [ p => [[1 => "$key: "], $input] ];
            }
        }
    }
    return @form;
}
1;
