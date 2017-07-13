package Test::Helper;

use strict;
use warnings;
use XML::LibXML;
use XML::LibXML::PrettyPrint;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
read_postgresql_dump create_sqlite_schemas select_all pretty_print_XML 
make_dataset make_layer);

sub read_postgresql_dump {
    my ($dump) = @_;
    my $schema;
    my %tables;
    my %table_dependencies;
    my %unique_indexes;
    open(my $fh, "<", $dump)
        or die "Can't open < $dump: $!";
    my $line = '';
    while (<$fh>) {
        #chomp;
        #s/\s+$//;
        next if /^\s+$/;
        next if /^--/;
        next unless $_;
        $line .= $_;
        if (/^SET search_path = (\w+)/) {
            $schema = $1;
        }
        #say STDERR "line=$line";
        if (/;$/) {
            $line =~ s/::text//;
            if ($line =~ /^CREATE TABLE (\w+)/) {
                my $name = $1;
                #say STDERR "table = $name";
                my ($cols) = $line =~ /\((.*)?\)/s;
                #say STDERR "cols = $cols";
                for my $col (split_nicely($cols)) {
                    #say STDERR "col=$col";
                    my ($c, $r) = $col =~ /^([\w"]+)\s+(.*)$/;
                    #say STDERR "$col => $c, $r";
                    $tables{$schema}{$name}{$c} = $r;
                }
            }
            if ($line =~ /^ALTER TABLE ONLY (\w+)/) {
                my $table = $1;
                if ($line =~ /PRIMARY KEY \((.+)?\)/) {
                    my $col = $1;
                    if ($col =~ /,/) {
                        $tables{$schema}{$table}{'+'}{$col} = "PRIMARY KEY ($col)";
                    } else {
                        $tables{$schema}{$table}{$col} .= ' PRIMARY KEY';
                    }
                } elsif ($line =~ /UNIQUE \((.*)?\)/) {
                    my $cols = $1;
                    if ($cols =~ /,/) {
                        $unique_indexes{$schema}{$table.'_ix'} = "$table($cols)";
                    } else {
                        $tables{$schema}{$table}{$cols} .= ' UNIQUE';
                    }
                } elsif ($line =~ /SET DEFAULT nextval/) {
                } elsif ($line =~ /FOREIGN KEY \((\w+)\) REFERENCES (\w+)\((\w+)\)/) {
                    my $col = $1;
                    my $f_table = $2;
                    my $f_col = $3;
                    $tables{$schema}{$table}{'+'}{$col} .= "FOREIGN KEY($col) REFERENCES $f_table($f_col)";
                    $table_dependencies{$table}{$f_table} = 1;
                }
                
            }
            $line = '';
        }
    }
    close $fh;
    return (\%tables, \%table_dependencies, \%unique_indexes);
}

sub create_sqlite_schemas {
    my ($tables, $deps, $indexes) = @_;
    my %schemas;
    for my $schema (sort keys %$tables) {
        my @lines;
        my @sorted;
        my %in_result;
        for my $table (keys %{$tables->{$schema}}) {
            topo_sort($deps, \@sorted, $table, \%in_result);
        }
        for my $table (@sorted) {
            my @cols;
            my $f = 1;
            for my $col (sort keys %{$tables->{$schema}{$table}}) {
                next if $col eq '+';
                my $c = $f ? '' : ",\n";
                push @cols, "$c  $col $tables->{$schema}{$table}{$col}";
                $f = 0;
            }
            next unless @cols;
            push @lines, "CREATE TABLE $table(\n";
            push @lines, @cols;
            for my $col (sort keys %{$tables->{$schema}{$table}{'+'}}) {
                push @lines, ",\n  $tables->{$schema}{$table}{'+'}{$col}";
            }
            push @lines, "\n);\n";
        }
        for my $index (sort keys %{$indexes->{$schema}}) {
            push @lines, "CREATE UNIQUE INDEX $index ON $indexes->{$schema}{$index};\n"
        }
        $schemas{$schema} = \@lines;
    }
    for my $schema (keys %schemas) {
        my $s = $schema.'.sql';
        open(my $fh, ">", $s)
            or die "Can't open < $s: $!";
        print $fh @{$schemas{$schema}};
        close $fh;
        unlink "$schema.db";
        system "sqlite3 $schema.db < $s";
    }
    return \%schemas;
}

sub split_nicely {
    my $s = shift;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    my @s = split /\s*,\n\s*/, $s;
    return @s;
}

sub topo_sort {
    my ($deps, $result, $item, $in_result) = @_;
    return if $in_result->{$item};
    for my $child (keys %{$deps->{$item}}) {
        next if $child eq $item;
        topo_sort($deps, $result, $child, $in_result);
    }
    push @$result, $item;
    $in_result->{$item} = 1;
}

sub select_all {
    my ($schema, $cols, $class) = @_;
    my @all;
    $schema->storage->dbh_do(sub {
        my (undef, $dbh) = @_;
        my $sth = $dbh->prepare("SELECT $cols FROM $class");
        $sth->execute;
        while (my @a = $sth->fetchrow_array) {
            push @all, \@a;
        }});
    return @all;
}

sub pretty_print_XML {
    my $xml = shift;
    my $parser = XML::LibXML->new(no_blanks => 1);
    my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");
    eval {
        my $dom = $parser->load_xml(string => $xml);
        $pp->pretty_print($dom);
        print STDERR $dom->toString;
    };
    if ($@) {
        say STDERR $xml;
    }
}

# the tile that we'll ask the layer to compute
{
    package Tile;
    my $epsg = 3067;
    my $x_min = 61600.000;
    my $y_max = 7304000.000;
    my $cell_wh = 20.0;
    my $data_wh = 3;
    my $data_dir = '/vsimem/';
    sub new {
        my ($class, $self) = @_;
        $self //= [
            $data_wh,
            $data_wh, 
            $x_min,
            $y_max,
            $x_min+$cell_wh*$data_wh,
            $y_max-$cell_wh*$data_wh
            ];
        bless $self, $class;
    }
    sub data_dir {
        return $data_dir;
    }
    sub epsg {
        return $epsg;
    }
    sub tile {
        my ($self) = @_;
        return @{$self}[0..1]; # width, height
    }
    *size = *tile;
    sub projwin {
        my ($self) = @_;
        return @{$self}[2..5]; # minx maxy maxx miny
    }
    sub geotransform {
        return ($x_min,$cell_wh,0, $y_max,0,-$cell_wh);
    }
}

sub make_dataset {
    my ($schema, $sequences, $tile, $datatype, $data, $style) = @_;
    # min_value, max_value, classes, style, descr
    my $min;
    my $max;
    for my $row (@$data) {
        for my $x (@$row) {
            $min = $x unless defined $min;
            $max = $x unless defined $max;
            $min = $x if $x < $min;
            $max = $x if $x > $max;
        }
    }
    unless ($style) {
        $style = {
            id => $sequences->{style},
            min => undef,
            max => undef,
            classes => undef,
            color_scale => 1
        };
        $sequences->{style}++;
    }
    $schema->resultset('Style')->new($style)->insert;
    my $id = $sequences->{dataset};
    $schema->resultset('Dataset')->update_or_new(
        {
            id => $id,
            name => "dataset_".$id,
            custodian => '',
            contact => '',
            descr => '',
            data_model => undef,
            is_a_part_of => undef,
            is_derived_from => undef,
            license => undef,
            attribution => '',
            disclaimer => '',
            path => $id.'.tiff',
            min_value => $min,
            max_value => $max,
            unit => undef,
            style => $style->{id}
        }, 
        {
            key => 'primary'
        })
        ->insert;
    my ($w,$h) = $tile->size;
    my $test = Geo::GDAL::Driver('GTiff')->Create(
        Name => $tile->data_dir.$id.".tiff",
        Type => $datatype, 
        Width => $w, 
        Height => $h)->Band;
    $test->Dataset->GeoTransform($tile->geotransform);
    $test->WriteTile($data);
    $sequences->{dataset}++;
    return $schema->resultset('Dataset')->single({id => $id});
}

sub make_layer {
    my ($args) = @_;
    my $id = $args->{id};
    my $schema = $args->{schema};
    if ($args->{use_class_id} > 1) {
        $schema->resultset('Style')->new({
            id => $args->{style}->{id},
            color_scale => $args->{style}->{color_scale}->id,
            min => $args->{style}->{min},
            max => $args->{style}->{max},
            classes => $args->{style}->{classes} })->insert;
        $schema->resultset('RuleSystem')->create({
            id => $id, 
            rule_class => $args->{rule_class}->id });
        $schema->resultset('Layer')->create({
            id => $id,
            layer_class => $args->{layer_class_id},
            use => 1,
            rule_system => $id,
            style => $args->{style}->{id} });
        for my $rule (@{$args->{rules}}) {
            # $args->{rule_class}->id and $rule->{data} must match...
            add_rule($id, $rule, $args);
        }
    }
    return SmartSea::Layer->new({
        debug => $args->{debug},
        epsg => $args->{tile}->epsg,
        tile => $args->{tile},
        schema => $schema,
        data_dir => $args->{tile}->data_dir,
        GDALVectorDataset => undef,
        cookie => '', 
        trail => $args->{use_class_id}.'_'.$id.'_all' });
}

sub add_rule {
    my ($rule_system, $data, $args) = @_;
    my $schema = $args->{schema};
    my $rule = {
        id => $args->{sequences}{rule},
        layer => $data->{layer},
        dataset => $data->{dataset},
        min_value => 0,
        max_value => 1,
        cookie => '',
        made => undef,
        rule_system => $rule_system
    };
    if ($data->{op}) {
        $rule->{op} = $data->{op};
        $rule->{value} = $data->{value};
    } else {
        $rule->{value_at_min} = $data->{'y_min'};
        $rule->{value_at_max} = $data->{'y_max'};
        $rule->{min_value} = $data->{x_min};
        $rule->{max_value} = $data->{x_max};
        $rule->{weight} = $data->{weight};
    }
    $schema->resultset('Rule')->new($rule)->insert;
    $args->{sequences}{rule}++;
}


1;
