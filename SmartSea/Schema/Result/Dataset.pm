package SmartSea::Schema::Result::Dataset;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core;

__PACKAGE__->table('data.datasets');
__PACKAGE__->add_columns(qw/id name custodian contact desc data_model is_a_part_of is_derived_from license attribution disclaimer path unit/);
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
    push @l, [li => [[b => "description"],[1 => " = ".$self->desc]]] if $self->desc;
    push @l, [li => [[b => "disclaimer"],[1 => " = ".$self->disclaimer]]] if $self->disclaimer;
    push @l, [li => [[b => "license"],[1 => " = "],
                     SmartSea::HTML->a(link => $self->license->name, 
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
    return [1 => 'to be done'];
}

sub li {
    my ($all, $parent, $id, $html, $uri, $allow_edit) = @_;
    my @li;
    for my $set (@$all) {
        my $sid = $set->id;
        unless (defined $id) {
            next if $parent->{$sid};
        } else {
            next unless $parent->{$sid} && $parent->{$sid} == $id;
        }
        my $li = [ $html->a(link => $set->name, url => $uri.'/'.$set->id) ];
        if ($allow_edit) {
            push @$li, (
                [1 => '  '],
                $html->a(link => "edit", url => $uri.'/'.$set->id.'?edit'),
                [1 => '  '],
                [input => {
                    type=>"submit", 
                    name=>$set->id, 
                    value=>"Delete",
                    onclick => "return confirm('Are you sure you want to delete this dataset?')"
                 }
                ]
            )
        }
        my $children = li($all, $parent, $sid, $html, $uri, $allow_edit);
        push @$li, [ul => $children] if @$children;
        push @li, [li => $li];
    }
    return \@li;
}

sub tree {
    my ($rs, $html, $uri, $allow_edit) = @_;
    my %parent;
    my @all;
    for my $set ($rs->search(undef, {order_by => ['me.name']})) {
        my $rel = $set->is_a_part_of // $set->is_derived_from;
        $parent{$set->id} = $rel->id if $rel;
        push @all, $set;
    }
    return [ul => li(\@all, \%parent, undef, $html, $uri, $allow_edit)];
}

sub HTML_list {
    my (undef, $rs, $uri, $allow_edit) = @_;
    my $html = SmartSea::HTML->new;
    my @body = (tree($rs, $html, $uri, $allow_edit));
    if ($allow_edit) {
        @body = ([ form => {action => $uri, method => 'POST'}, [@body] ]);
        push @body, $html->a(link => 'add', url => $uri.'/new');
    }
    return \@body;
}

1;
