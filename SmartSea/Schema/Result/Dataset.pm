package SmartSea::Schema::Result::Dataset;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::Core;
use SmartSea::HTML qw(:all);
use PDL;
use PDL::NiceSlice;

my %attributes = (
    name            => { i => 1,  input => 'text',    size => 20 },
    custodian       => { i => 2,  input => 'lookup',  class => 'Organization', allow_null => 1 },
    contact         => { i => 3,  input => 'text',    size => 20 },
    descr           => { i => 4,  input => 'textarea' },
    data_model      => { i => 5,  input => 'lookup',  class => 'DataModel', allow_null => 1 },
    is_a_part_of    => { i => 6,  input => 'lookup',  class => 'Dataset',   allow_null => 1 },
    is_derived_from => { i => 7,  input => 'lookup',  class => 'Dataset',   allow_null => 1 },
    license         => { i => 8,  input => 'lookup',  class => 'License',   allow_null => 1 },
    attribution     => { i => 9,  input => 'text',    size => 40 },
    disclaimer      => { i => 10, input => 'text',    size => 80 },
    path            => { i => 11, input => 'text',    size => 30 },
    unit            => { i => 12, input => 'lookup',  class => 'Unit',      allow_null => 1 },
    style           => { i => 16, input => 'object',  class => 'Style' }
    );

__PACKAGE__->table('datasets');
__PACKAGE__->add_columns('id', keys %attributes);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(custodian => 'SmartSea::Schema::Result::Organization');
__PACKAGE__->belongs_to(data_model => 'SmartSea::Schema::Result::DataModel');
__PACKAGE__->belongs_to(is_a_part_of => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(is_derived_from => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(license => 'SmartSea::Schema::Result::License');
__PACKAGE__->belongs_to(unit => 'SmartSea::Schema::Result::Unit');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');

sub attributes {
    return \%attributes;
}

sub relationship_methods {
    my $self = shift;
    return { };
}

sub my_unit {
    my $self = shift;
    return $self->unit if defined $self->unit;
    return $self->is_a_part_of->my_unit if defined $self->is_a_part_of;
    return $self->is_derived_from->my_unit if defined $self->is_derived_from;
    return undef;
}

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
*lineage = *long_name;

sub HTML_div {
    my ($self, $attributes, %args) = @_;

    my @div = ([h2 => $self->name]);
    
    if ($self->path) {
        my $info = '';
        if ($self->path =~ /^PG:/) {
            my $dsn = $self->path;
            $dsn =~ s/^PG://;
            $info = `ogrinfo -so PG:"dbname=$args{dbname} user='$args{user}' password='$args{pass}'" '$dsn'`;
            $info =~ s/user='(.*?)'/user='xxx'/;
            $info =~ s/password='(.*?)'/password='xxx'/;
        } else {
            my $path = $args{data_dir}.$self->path;
            my @info = `gdalinfo $path`;
            my $table;
            for (@info) {
                $table = 1 if /<GDALRasterAttributeTable>/;
                next if $table;
                $info .= $_;
                $table = 0 if /<\/GDALRasterAttributeTable>/;
            }
        }
        push @div, [h3 => "GDAL info of ".$self->name.":"], [pre => $info];
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

    push @l, $self->style->li if $self->style;
    
    push @div, [ul => \@l] if @l;

    my $rel = $self->is_a_part_of;
    if ($rel) {
        push @div, [h3 => "'".$self->name."' is a part of '".$rel->name."'"];
        push @div, $rel->HTML_div({}, %args);
    }
    $rel = $self->is_derived_from;
    if ($rel) {
        push @div, [h3 => "'".$self->name."' is derived from '".$rel->name."'"];
        push @div, $rel->HTML_div({}, %args);
    }

    return [div => $attributes, @div];
}

sub HTML_form {
    my ($self, $attributes, $values, %args) = @_;

    my @form;

    my $new = 1;
    my $compute = 0;
    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Dataset')) {

        $compute = 1 if $self->path;
        
        if ($compute && $args{parameters}{compute}) {
            # min and max
            # assuming one band
            my $b = Geo::GDAL::Open($args{data_dir}.$self->path)->Band;
            $b->ComputeStatistics(0);
            $values->{min} = $b->GetMinimum;
            $values->{max} = $b->GetMaximum;
        }
        
        for my $key (keys %attributes) {
            next unless defined $self->$key;
            next if defined $values->{$key};
            $values->{$key} = $self->$key;
        }
        push @form, [input => {type => 'hidden', name => 'id', value => $self->id}];
        $new = 0;
    }

    push @form, widgets(\%attributes, $values, $args{schema});

    if ($compute) {
        push @form, button(value => "Compute min & max from dataset");
        push @form, ['br'], ['br'];
    }

    push @form, button(value => $new ? "Create" : "Store");
    push @form, [1 => ' '];
    push @form, button(value => "Cancel");

    return [form => $attributes, @form];
}

sub li {
    my ($all, $parent, $id, %args) = @_;
    my @li;
    for my $set (@$all) {
        my $sid = $set->id;
        unless (defined $id) {
            next if $parent->{$sid};
        } else {
            next unless $parent->{$sid} && $parent->{$sid} == $id;
        }
        my $li = item($set->name, $set->id, %args, ref => 'this dataset');
        my @item = @$li;
        my @l = li($all, $parent, $sid, %args);
        push @item, [ul => \@l] if @l;
        push @li, [li => \@item];
    }
    return @li;
}

sub tree {
    my ($objs, %args) = @_;
    my %parent;
    my @all;
    for my $set (sort {$a->name cmp $b->name} @$objs) {
        my $rel = $set->is_a_part_of // $set->is_derived_from;
        $parent{$set->id} = $rel->id if $rel;
        push @all, $set;
    }
    return li(\@all, \%parent, undef, %args);
}

sub HTML_list {
    my (undef, $objs, %args) = @_;

    my @li;
    my %has;
    if ($args{plan}) {
        my %li;
        for my $dataset (@$objs) {
            my $u = $dataset->long_name;
            $has{$dataset->id} = 1;
            my $ref = 'this dataset';
            $li{$u} = item([b => $u], 'dataset:'.$dataset->id, %args, ref => $ref);
        }
        for my $dataset (sort keys %li) {
            push @li, [li => $li{$dataset}];
        }
    } else {
        @li = tree($objs, %args);
    }

    if ($args{edit}) {
        if ($args{plan}) {
            my @objs;
            for my $obj ($args{schema}->resultset('Dataset')->all) {
                next unless $obj->path;
                next if $has{$obj->id};
                push @objs, $obj;
            }
            if (@objs) {
                my $drop_down = drop_down(name => 'dataset', objs => \@objs);
                push @li, [li => [$drop_down, [0 => ' '], button(value => 'Add', name => 'dataset')]];
            }
        } else {
            my $name = text_input(name => 'name');
            push @li, [li => [$name, 
                              [0 => ' '],
                              button(value => 'Create', name => 'dataset')]];
        }
    }
    
    my $ret = [ul => \@li];
    return [ li => [0 => 'Datasets:'], $ret ] if $args{named_item};
    return $ret;
}

sub Piddle {
    my ($self, $rules) = @_;

    my $path = $self->path;
    my $tile = $rules->{tile};

    if ($path =~ /^PG:/) {
        
        my ($w, $h) = $tile->tile;
        my $ds = Geo::GDAL::Driver('GTiff')->Create(Name => "/vsimem/r.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);        
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>$rules->{epsg}));

        $path =~ s/^PG://;
        $path =~ s/\./"."/;
        $path = '"'.$path.'"';
        my $sql = "select gid,st_transform(geom,$rules->{epsg}) as geom from $path";
        $rules->{GDALVectorDataset}->Rasterize($ds, [-burn => 1, -sql => $sql]);
        
        return $ds->Band->Piddle;
        
    } else {
        
        my $b;
        eval {

            if ($rules->{epsg} == 3067) {
            
                $b = Geo::GDAL::Open("$rules->{data_dir}$path")
                    ->Translate( "/vsimem/tmp.tiff", 
                                 [ -of => 'GTiff',
                                   -r => 'nearest',
                                   -outsize , $tile->tile,
                                   -projwin, $tile->projwin ])
                    ->Band;

            } else {

                my $e = $tile->extent;
                $b = Geo::GDAL::Open("$rules->{data_dir}$path")
                    ->Warp( "/vsimem/tmp.tiff", 
                            [ -of => 'GTiff', 
                              -r => 'near' ,
                              -t_srs => 'EPSG:'.$rules->{epsg},
                              -te => @$e,
                              -ts => $tile->tile ])
                    ->Band;
            }
            
        };
        my $pdl;
        if ($@) {
            $pdl = zeroes($tile->tile);
            $pdl = $pdl->setbadif($pdl == 0);
        } else {
            $pdl = $b->Piddle;
            
            my $bad = $b->NoDataValue();
        
            # this is a hack
            if (defined $bad) {
                if ($bad < -1000) {
                    $pdl = $pdl->setbadif($pdl < -1000);
                } elsif ($bad > 1000) {
                    $pdl = $pdl->setbadif($pdl > 1000);
                } else {
                    $pdl = $pdl->setbadif($pdl == $bad);
                }
            }
        }

        return $pdl;
    }
}

1;
