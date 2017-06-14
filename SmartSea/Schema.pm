package SmartSea::Schema;

use DBIx::Class::Schema;

use base qw/DBIx::Class::Schema/;

__PACKAGE__->load_namespaces();

sub simple_sources {
    my $self = shift;
    my %sources = map {$_ => 1} $self->sources;
    my (%ok, %not_ok);
    my %simple;
    for my $source ($self->sources) {
        if ($source =~ /2/) {
            delete $sources{$source};
            next;
        }
        my $is_not_simple;
        my $class = 'SmartSea::Schema::Result::'.$source;
        
        # is the class non-independent related class?
        my $rs = $class->relationship_hash if $class->can('relationship_hash');
        for my $r (keys %$rs) {
            $is_not_simple = 1 unless $is_not_simple;
            next if $rs->{$r}{stop_edit} || (defined $rs->{$r}{edit} && $rs->{$r}{edit} == 0);
            delete $sources{$rs->{$r}{source}} unless $source eq $rs->{$r}{source};
        }
        
        # is the class non-independent part class?
        my $cols_info = $class->can('my_columns_info') ? $class->my_columns_info : $class->columns_info;
        for my $col (keys %$cols_info) {
            $is_not_simple = $cols_info->{$col}{source} unless $is_not_simple;
            if ($cols_info->{$col}{is_superclass}) {
                $not_ok{$source} = 1;
                last;
            }
            my $col_source = $cols_info->{$col}{source};
            next unless $col_source;
            if ($cols_info->{$col}{is_part}) {
                $not_ok{$col_source} = 1;
            } else {
                $ok{$col_source} = 1 if $not_ok{$col_source};
            }
        }

        unless ($is_not_simple) {
            delete $sources{$source};
            $simple{$source} = 1;
        }
    }
    for my $source (keys %not_ok) {
        next if $ok{$source};
        delete $sources{$source};
    }
    return (\%sources, \%simple);
}

1;
