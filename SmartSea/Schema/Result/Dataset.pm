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

sub children_listers {
    return { parts => [dataset => 2], derivatives => [dataset => 2] };
}

sub for_child_form {
    my ($self, $kind) = @_;
    return hidden(is_a_part_of => $self->id) if $kind eq 'parts';
    return hidden(is_derived_from => $self->id) if $kind eq 'derivatives';
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
