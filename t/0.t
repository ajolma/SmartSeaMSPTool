use Modern::Perl;
use File::Basename;
use Test::More;

use_ok('SmartSea::Schema');

# create the test databases

my ($name,$path,$suffix) = fileparse($0, 'pl', 't');

my ($tables, $deps, $indexes) = read_postgresql_dump($path.'../schema.sql');
my $schemas = create_sqlite_schemas($tables, $deps, $indexes);

for my $schema (keys %$schemas) {
    my $s = $schema.'.sql';
    open(my $fh, ">", $s)
        or die "Can't open < $s: $!";
    print $fh @{$schemas->{$schema}};
    close $fh;
    unlink "$schema.db";
    system "sqlite3 $schema.db < $s";
}

my $data_schema  = SmartSea::Schema->connect('dbi:SQLite:data.db');
my $tool_schema  = SmartSea::Schema->connect('dbi:SQLite:tool.db');

my $plan_rs = $tool_schema->resultset('Plan');
can_ok($plan_rs->result_class, qw/id name uses datasets/);

unlink "data.db";
unlink "tool.db";
unlink "data.sql";
unlink "tool.sql";

done_testing();

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
        chomp;
        s/\s+$//;
        next if /^--/;
        next unless $_;
        $line .= $_;
        if (/^SET search_path = (\w+)/) {
            $schema = $1;
        }
        if (/;$/) {
            $line =~ s/::text//;
            if ($line =~ /^CREATE TABLE (\w+)/) {
                my $name = $1;
                my ($cols) = $line =~ /\((.*)?\)/;
                for my $col (split_nicely($cols)) {
                    my ($c, $r) = $col =~ /^([\w"]+)\s+(.*)$/;
                    #say "$col => $c, $r";
                    $tables{$schema}{$name}{$c} = $r;
                }
            }
            if ($line =~ /^ALTER TABLE ONLY (\w+)/) {
                my $table = $1;
                if ($line =~ /PRIMARY KEY \((\w+)/) {
                    my $col = $1;
                    $tables{$schema}{$table}{$col} .= ' PRIMARY KEY';
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
            push @lines, "CREATE TABLE $table(\n";
            my $f = 1;
            for my $col (sort keys %{$tables->{$schema}{$table}}) {
                next if $col eq '+';
                my $c = $f ? '' : ",\n";
                push @lines, "$c  $col $tables->{$schema}{$table}{$col}";
                $f = 0;
            }
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
    return \%schemas;
}

sub split_nicely {
    my $s = shift;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    my @s = split /\s*,\s*/, $s;
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
