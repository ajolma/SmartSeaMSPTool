package SmartSea::Schema::Result::Dataset;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Core;
use SmartSea::HTML qw(:all);
use PDL;
use PDL::NiceSlice;

my @columns = (
    id              => {},
    name            => { data_type => 'text',    size => 20 },
    custodian       => { is_foreign_key => 1, source => 'Organization', allow_null => 1 },
    contact         => { data_type => 'text',    size => 20 },
    descr           => { data_type => 'textarea' },
    data_model      => { is_foreign_key => 1, source => 'DataModel', allow_null => 1 },
    is_a_part_of    => { is_foreign_key => 1, source => 'Dataset',   allow_null => 1, self_ref => 1 },
    is_derived_from => { is_foreign_key => 1, source => 'Dataset',   allow_null => 1, self_ref => 1 },
    license         => { is_foreign_key => 1, source => 'License',   allow_null => 1 },
    attribution     => { data_type => 'text',    size => 40 },
    disclaimer      => { data_type => 'text',    size => 80 },
    path            => { data_type => 'text',    size => 30, empty_is_null => 1 },
    db_table        => { data_type => 'text',    size => 30 },
    min_value       => { data_type => 'text',    size => 20, empty_is_null => 1 },
    max_value       => { data_type => 'text',    size => 20, empty_is_null => 1 },
    data_type       => { is_foreign_key => 1, source => 'NumberType', allow_null => 1 },
    class_semantics => { data_type => 'text',    size => 40, empty_is_null => 1 },
    unit            => { is_foreign_key => 1, source => 'Unit',       allow_null => 1 },
    style           => { is_foreign_key => 1,  source => 'Style', is_composition => 1 }
    );

__PACKAGE__->table('datasets');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(custodian => 'SmartSea::Schema::Result::Organization');
__PACKAGE__->belongs_to(data_model => 'SmartSea::Schema::Result::DataModel');
__PACKAGE__->belongs_to(is_a_part_of => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(is_derived_from => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(license => 'SmartSea::Schema::Result::License');
__PACKAGE__->belongs_to(unit => 'SmartSea::Schema::Result::Unit');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');

__PACKAGE__->has_many(parts => 'SmartSea::Schema::Result::Dataset', 'is_a_part_of');
__PACKAGE__->has_many(derivatives => 'SmartSea::Schema::Result::Dataset', 'is_derived_from');

sub children_listers {
    return {
        parts => {
            source => 'Dataset',
            self_ref => 'is_a_part_of',
            class_name => 'Datasets in this group',
            cannot_add_remove_children => 1,
            for_child_form => sub {
                my ($self, $children) = @_;
                return hidden(is_a_part_of => $self->{object}->id);
            }
        },
        derivatives => {
            source => 'Dataset',
            self_ref => 'is_derived_from',
            class_name => 'Derivative datasets',
            cannot_add_remove_children => 1,
            for_child_form => sub {
                my ($self, $children) = @_;
                return hidden(is_derived_from => $self->{object}->id);
            }
        }
    };
}

sub lineage {
    my $self = shift;
    my $lineage = $self->name;
    $lineage .= ' (a part of) '.$self->is_a_part_of->name if $self->is_a_part_of;
    $lineage .= ' (derived from) '.$self->is_derived_from->name if $self->is_derived_from;
    return $lineage;
}

sub my_unit {
    my $self = shift;
    return $self->unit if defined $self->unit;
    return $self->is_a_part_of->my_unit if defined $self->is_a_part_of;
    return $self->is_derived_from->my_unit if defined $self->is_derived_from;
    return undef;
}

sub info {
    my ($self, $args) = @_;
    return '' unless $self->path;
    my $info = '';
    if ($self->path =~ /^PG:/) {
        my $dsn = $self->path;
        $dsn =~ s/^PG://;
        $info = `ogrinfo -so PG:"dbname=$args->{dbname} user='$args->{user}' password='$args->{pass}'" '$dsn'`;
        $info =~ s/user='(.*?)'/user='xxx'/;
        $info =~ s/password='(.*?)'/password='xxx'/;
    } else {
        my $path = $args->{data_dir}.$self->path;
        my @info = `gdalinfo $path`;
        my $table;
        for (@info) {
            $table = 1 if /<GDALRasterAttributeTable>/;
            next if $table;
            $info .= $_;
            $table = 0 if /<\/GDALRasterAttributeTable>/;
        }
    }
    return [pre => $info];
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
