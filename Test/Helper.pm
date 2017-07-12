package Test::Helper;

use strict;
use warnings;
use XML::LibXML;
use XML::LibXML::PrettyPrint;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(read_postgresql_dump create_sqlite_schemas select_all pretty_print_XML);

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

1;
