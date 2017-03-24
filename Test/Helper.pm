package Test::Helper;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(one_schema read_postgresql_dump create_sqlite_schemas);

{
    package Schema;
    sub new {
        my ($class, $self) = @_;
        return bless $self, $class;
    }
    sub resultset {
        my ($self, $class) = @_;
        for my $s (@$self) {
            return $s->[0]->resultset($class) if $s->[1]{$class};
        }
        say STDERR "missing $class";
    }
    sub sources {
        my $self = shift;
        my @s;
        for my $s (@$self) {
            push @s, $s->[0]->sources;
        }
        return @s;
    }
}

sub one_schema {
    my $data_schema  = SmartSea::Schema->connect(
        'dbi:SQLite:data.db', undef, undef, 
        {on_connect_do => ["ATTACH 'tool.db' AS aux"]});
    my $tool_schema  = SmartSea::Schema->connect(
        'dbi:SQLite:tool.db', undef, undef, 
        {on_connect_do => ["ATTACH 'data.db' AS aux"]});
    return Schema->new(
        [
         [$data_schema, {
             Dataset => 1,
             License => 1,
             Organization => 1,
             Unit => 1
          }], 
         [$tool_schema, 
          { Style => 1,
            ColorScale => 1,
            Plan => 1, 
            UseClass => 1, 
            Use => 1, 
            LayerClass => 1, 
            Layer => 1, 
            RuleClass => 1,
            Op => 1,
            Rule => 1,
            UseClass2Activity => 1,
            PressureCategory => 1,
            Activity2Pressure => 1,
            Activity => 1,
            Pressure => 1,
            Impact => 1,
            EcosystemComponent => 1,
            Impact => 1,
            EcosystemComponent => 1,
            Pressure => 1,
            PressureCategory => 1,
            Use2Activity => 1,
            DataModel => 1,
            Activity => 1,
            Activity2Pressure => 1,
            NumberType => 1
          }]]);
}

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
            my @cols;
            my $f = 1;
            for my $col (sort keys %{$tables->{$schema}{$table}}) {
                next if $col eq '+';
                my $c = $f ? '' : ",\n";
                push @cols, "$c $col $tables->{$schema}{$table}{$col}";
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

1;
