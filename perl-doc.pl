use Modern::Perl;
use Geo::OGC::Service;
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use Clone 'clone';

my $xml = $ARGV[0] && $ARGV[0] eq '--xml';

{
    package HTML;
    our @ISA = qw(Geo::OGC::Service::XMLWriter);
    sub new {
        my $class = shift;
        my $self = bless {}, $class;
        $self->element(@_) if @_;
        return $self;
    }
    sub element {
        my $self = shift;
        my ($tag) = @_;
        if (@_ == 2 && ($tag eq 'script' || $tag eq 'span')) {
            push @_, '';
        }
        $self->SUPER::element(@_);
    }
    sub write {
        my ($self, $line) = @_;
        push @{$self->{cache}}, $line;
    }
    sub html {
        my $self = shift;
        $self->element(@_) if @_;
        return '<!DOCTYPE html>'.join('', @{$self->{cache}});
    }
}

# assumes
# <out_dir>/scripts/linenumber.js
# <out_dir>/styles/styles files
# <out_dir>/fonts/font files

my $classes = {
    meta => {
        out_dir => 'doc',
    }
};
read_file_for_doc('SmartSea/Object.pm', $classes);
for my $name (sort keys %$classes) {
    next if $name eq 'meta';
    document_a_class($name, $classes);
}

sub read_file_for_doc {
    my ($file, $classes) = @_;
    open(my $fh, "<", $file) or die "Can't open < $file: $!";
    my $doc;
    my $class;
    my $topic;
    my $line = 0;
    while (<$fh>) {
        $line += 1;
        chomp;
        if (/^##/) {
            $topic = 'main';
            $doc = {descr => ''};
            next;
        }
        if (/^#/) {
            next unless $doc;
            s/^#\s*//;
            if (/^\@param\s+\{(\w+)\}\s+(\w+)\s+(.*)/) {
                my ($type, $name, $descr) = ($1, $2, $3);
                $descr =~ s/^-\s+//;
                $doc->{params} = [] unless $doc->{params};
                push @{$doc->{params}}, {name => $name, type => $type, descr => $descr};
                $topic = 'param';
                next;
            }
            if (/^\@class-method/) {
                $doc->{class_method} = 1;
                next;
            }
            if ($topic eq 'param') {
                my $i = $#{$doc->{params}};
                $doc->{params}[$i]{descr} .= ' '.$_;
                next;
            }
            $doc->{descr} .= ' '.$_;
            next;
        }
        if (/^package\s+([\w:]+)/) {
            next unless $doc;
            $class = $1;            
            $classes->{$class} = clone($doc);
            undef $doc;
            my $href = $class;
            $href =~ s/::/_/g;
            $classes->{$class}{href} = $href.'.html';
            $classes->{$class}{file} = $file;
            next;
        }
        if (/^sub\s+new/) {
            $classes->{$class}{constructor} = clone($doc);
            undef $doc;
            $classes->{$class}{constructor}{meta} = {
                source => $file,
                line => $line
            };
            next;
        }
        if (/^sub\s+(\w+)/) {
            my $name = $1;
            $doc->{meta} = {
                source => $file,
                line => $line
            };
            $classes->{$class}{methods}{$name} = clone($doc);
            next;
        }
    }
    close $fh;
}

sub parameter_table {
    my $params = shift;
    my @tbody;
    for my $param (@$params) {
        push @tbody, [tr =>
            [td => {class => "name"}, [code => $param->{name}]],
            [td => {class => "type"}, 
                [span => {class => "param-type"}, [a => {href => "foo#".$param->{name}}, $param->{type}]]],
            [td => {class => "description last"}, $param->{descr}]
        ]
    }
    [
        [thead => [tr => 
            [th => 'Name'],
            [th => 'Type'],
            [th => {class => "last"}, 'Description']]
        ],
        [tbody => \@tbody]
    ];
}

sub details {
    my $method = shift;
    [[dt => {class => "tag-source"}, 'Source:'],
     [dd => {class => "tag-source"},
         [ul => {class => "dummy"},
             [li => 
                 [a => {href => "foo"}, $method->{source}],
                 [0 => ', '],
                 [a => {href => $method->{source}.".html#line".$method->{line}}, 'line '.$method->{line}]
             ]
         ]
     ]];
}

sub document_a_class {
    my ($name, $classes) = @_;
    my $class = $classes->{$name};
    
    my $head = [
        [meta => {charset => 'utf-8'}],
        [title => 'Perl-Doc: Class: '.$name],
        [script => {src => "https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js"}],
        [link => {type => "text/css", rel => "stylesheet", href => "styles/prettify-tomorrow.css"}],
        [link => {type => "text/css", rel => "stylesheet", href => "styles/jsdoc-default.css"}],
    ];
    
    my $header = [
        h2 =>
        [span => {class => "attribs"}, [span => {class => "type-signature"}]],
        [0 => 'Constructor'],
        [span => {class => "signature"}],
        [span => {class => "type-signature"}]
    ];

    my @params;
    for my $param (@{$class->{constructor}{params}}) {
        push @params, $param->{name};
    }
    
    my $article = [
        [div => {class => "container-overview"},
            [h4 => {class => "name", id => "MSP"},
                [span => {class => "type-signature"}],
                [0 => $name.'->new'],
                [span => {class => "signature"}, '('.join(',', @params).')']
            ],
            [div => {class => "description"}, $class->{descr}],
            [h5 => 'Parameters:'],
            [table => {class => "params"}, parameter_table($class->{constructor}{params})],
            [dl => {class => "details"}, details($class->{constructor}{meta})]
        ],
    ];
    
    push @$article, [h3 => {class => "subsection-title"}, 'Class Methods'];
    for my $method (@{$class->{methods}}) {
        next unless $method->{class_method};
        my @params;
        for my $param (@{$method->{params}}) {
            push @params, $param->{name};
        }
        push @$article, [h4 => {class => 'name', id => $method->{name}},
            [span => {class => "type-signature"}],
            [0 => $method->{name}],
            [span => {class => "signature"}, '('.join(', ', @params).')'],
            [span => {class => "type-signature"}]
        ];
        push @$article, [div => {class => 'description'}, $method->{descr}];
        push @$article, [dl => {class => "details"}, details($method->{meta})];
        push @$article, [h5 => 'Example'];
        push @$article, [pre => {class => "prettyprint"}, [code => $method->{code}]];
    }

    push @$article, [h3 => {class => "subsection-title"}, 'Object Methods'];
    for my $method (@{$class->{methods}}) {
        next unless $method->{object_method};
        my @params;
        for my $param (@{$method->{params}}) {
            push @params, $param->{name};
        }
        push @$article, [h4 => {class => 'name', id => $method->{name}},
            [span => {class => "type-signature"}],
            [0 => $method->{name}],
            [span => {class => "signature"}, '('.join(', ', @params).')'],
            [span => {class => "type-signature"}]
        ];
        push @$article, [div => {class => 'description'}, $method->{descr}];
        push @$article, [dl => {class => "details"}, details($method->{meta})];
        push @$article, [h5 => 'Example'];
        push @$article, [pre => {class => "prettyprint"}, [code => $method->{code}]];
    }

    my $main = [
        [h1 => {class => "page-title"}, 'Class: '.$name],
        [section => [header => $header], [article => $article]]
    ];

    my @ul;
    for my $name (sort keys %$classes) {
        next if $name eq 'meta';
        push @ul, [li => [a => {href => $classes->{$name}{href}}, $name]];
    }
    
    my $nav = [
        [h2 => [a => {href => 'foo'}, 'Home']],
        [h3 => 'Classes'],
        [ul => \@ul],
        [h3 => [a => {href => 'foo'}, 'Global']]
    ];
    
    my $perl_doc = [a => {href => 'foobar'}, 'Perl-Doc 0.01'];
    my $date = `date`; chomp $date;
    
    my $body = [
        [div => {id => 'main'}, $main],
        [nav => $nav],
        [br => {class => "clear"}],
        [footer => [0 => 'Documentation generated by '],$perl_doc,[0 => " on $date"]],
        [script => {src => "scripts/linenumber.js"}, '']
    ];

    my $html = HTML->new(html => [head => $head],[body => $body])->html;
    
    if ($xml) {
        print XML::LibXML::PrettyPrint
            ->new(indent_string => "  ")
            ->pretty_print(XML::LibXML->new(no_blanks => 1)
                ->load_xml(string => $html))
            ->toString;
    } else {
        mkdir $classes->{meta}{out_dir};
        my $name = $classes->{meta}{out_dir}.'/'.$class->{href};
        open(my $fh, ">", $name) or die "Can't open > $name: $!";
        say $fh $html;
        close $fh;
    }
    
}
