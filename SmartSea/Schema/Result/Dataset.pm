package SmartSea::Schema::Result::Dataset;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core;
use SmartSea::HTML qw(:all);

my %attributes = (
        name => {
            i => 1,
            type => 'text',
            size => 20,
        },
        custodian => {
            i => 2,
            type => 'lookup',
            class => 'Organization',
            allow_null => 1
        },
        contact => {
            i => 3,
            type => 'text',
            size => 20,
        },
        descr => {
            i => 4,
            type => 'textarea'
        },
        data_model => {
            i => 5,
            type => 'lookup',
            class => 'DataModel',
            allow_null => 1
        },
        is_a_part_of => {
            i => 6,
            type => 'lookup',
            class => 'Dataset',
            allow_null => 1
        },
        is_derived_from => {
            i => 7,
            type => 'lookup',
            class => 'Dataset',
            allow_null => 1
        },
        license => {
            i => 8,
            type => 'lookup',
            class => 'License',
            allow_null => 1
        },
        attribution => {
            i => 9,
            type => 'text',
            size => 40,
        },
        disclaimer => {
            i => 10,
            type => 'text',
            size => 80,
        },
        path => {
            i => 11,
            type => 'text',
            size => 30,
        },
        unit => {
            i => 12,
            type => 'lookup',
            class => 'Unit',
            allow_null => 1
        }
    );

__PACKAGE__->table('data.datasets');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(custodian => 'SmartSea::Schema::Result::Organization');
__PACKAGE__->belongs_to(data_model => 'SmartSea::Schema::Result::DataModel');
__PACKAGE__->belongs_to(is_a_part_of => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(is_derived_from => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(license => 'SmartSea::Schema::Result::License');
__PACKAGE__->belongs_to(unit => 'SmartSea::Schema::Result::Unit');

sub long_name {
    my ($self) = @_;
    my $name = "'".$self->name."'";
    my $rel = $self->is_a_part_of;
    if ($rel) {
        $name .= " of ".$rel->long_name;
    }
    $rel = $self->is_derived_from;
    if ($rel) {
        $name .= " from ".$rel->long_name;
    }
    return $name;
}
*title = *long_name;

sub HTML_text {
    my ($self, $config) = @_;

    my @data = ([h2 => $self->name]);
    
    if ($self->path) {
        my $info = '';
        if ($self->path =~ /^PG:/) {
            my $dsn = $self->path;
            $dsn =~ s/^PG://;
            $info = `ogrinfo -so PG:"dbname=$config->{dbname} user='$config->{user}' password='$config->{pass}'" '$dsn'`;
            $info =~ s/user='(.*?)'/user='xxx'/;
            $info =~ s/password='(.*?)'/password='xxx'/;
        } else {
            my $path = $config->{data_path}.'/'.$self->path;
            my @info = `gdalinfo $path`;
            my $table;
            for (@info) {
                $table = 1 if /<GDALRasterAttributeTable>/;
                next if $table;
                $info .= $_;
                $table = 0 if /<\/GDALRasterAttributeTable>/;
            }
        }
        push @data, [h3 => "GDAL info of ".$self->name.":"], [pre => $info];
    }

    my @l;
    push @l, [li => [[b => 'custodian'],[1 => " = ".$self->custodian->name]]] if $self->custodian;
    if ($self->contact) {
        my $c = $self->contact;
        # remove email
        $c =~ s/\<.+?\>//;
        push @l, [li => [[b => "contact"],[1 => " = ".$c]]];
    }
    push @l, [li => [[b => "description"],[1 => " = ".$self->descr]]] if $self->descr;
    push @l, [li => [[b => "disclaimer"],[1 => " = ".$self->disclaimer]]] if $self->disclaimer;
    push @l, [li => [[b => "license"],[1 => " = "],
                     a(link => $self->license->name, 
                       url => $self->license->url)]] if $self->license;
    push @l, [li => [[b => "attribution"],[1 => " = ".$self->attribution]]] if $self->attribution;
    push @l, [li => [[b => "data model"],[1 => " = ".$self->data_model->name]]] if $self->data_model;
    push @l, [li => [[b => "unit"],[1 => " = ".$self->unit->name]]] if $self->unit;
    push @l, [li => [[b => "path"],[1 => " = ".$self->path]]] if $self->path;
    push @data, [ul => \@l] if @l;

    my $rel = $self->is_a_part_of;
    if ($rel) {
        push @data, [h3 => "'".$self->name."' is a part of '".$rel->name."'"];
        push @data, @{$rel->HTML_text($config)};
    }
    $rel = $self->is_derived_from;
    if ($rel) {
        push @data, [h3 => "'".$self->name."' is derived from '".$rel->name."'"];
        push @data, @{$rel->HTML_text($config)};
    }

    return \@data;
}

sub HTML_form {
    my ($self, $config, $values) = @_;

    my @ret;

    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Dataset')) {
        for my $key (keys %attributes) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
        push @ret, [input => {type => 'hidden', name => 'id', value => $self->id}];
    }

    my $widgets = widgets(\%attributes, $values, $config->{schema});

    for my $key (sort {$attributes{$a}{i} <=> $attributes{$b}{i}} keys %attributes) {
        push @ret, [ p => [[1 => "$key: "], $widgets->{$key}] ];
    }

    push @ret, button(value => "Store");
    push @ret, [1 => ' '];
    push @ret, button(value => "Cancel");
    return \@ret;
}

sub li {
    my ($all, $parent, $id, $uri, $edit) = @_;
    my @li;
    for my $set (@$all) {
        my $sid = $set->id;
        unless (defined $id) {
            next if $parent->{$sid};
        } else {
            next unless $parent->{$sid} && $parent->{$sid} == $id;
        }
        my $li = item($set->name, $set->id, $uri, $edit, 'this dataset');
        my $children = li($all, $parent, $sid, $uri, $edit);
        push @$li, [ul => $children] if @$children;
        push @li, [li => $li];
    }
    return \@li;
}

sub tree {
    my ($objs, $uri, $edit) = @_;
    my %parent;
    my @all;
    for my $set (sort {$a->name cmp $b->name} @$objs) {
        my $rel = $set->is_a_part_of // $set->is_derived_from;
        $parent{$set->id} = $rel->id if $rel;
        push @all, $set;
    }
    return [ul => li(\@all, \%parent, undef, $uri, $edit)];
}

sub HTML_list {
    my (undef, $objs, $uri, $edit) = @_;
    my @body = (tree($objs, $uri, $edit));
    if ($edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, a(link => 'add', url => $uri.'/new');
    }
    return \@body;
}

1;
