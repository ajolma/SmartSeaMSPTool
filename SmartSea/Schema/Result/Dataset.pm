package SmartSea::Schema::Result::Dataset;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Schema::Result::NumberType qw(:all);
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use PDL;

my @columns = (
    id              => {},
    name            => { data_type => 'text',    html_size => 20, not_null => 1 },
    custodian       => { is_foreign_key => 1, source => 'Organization' },
    contact         => { data_type => 'text',    html_size => 20 },
    descr           => { html_input => 'textarea' },
    data_model      => { is_foreign_key => 1, source => 'DataModel' },
    is_a_part_of    => { is_foreign_key => 1, source => 'Dataset', self_ref => 1 },
    is_derived_from => { is_foreign_key => 1, source => 'Dataset', self_ref => 1 },
    license         => { is_foreign_key => 1, source => 'License' },
    attribution     => { data_type => 'text',    html_size => 40 },
    disclaimer      => { data_type => 'text',    html_size => 80 },
    path            => { data_type => 'text',    html_size => 30 },
    db_table        => { data_type => 'text',    html_size => 30 },
    min_value       => { data_type => 'double',  html_size => 20 },
    max_value       => { data_type => 'double',  html_size => 20 },
    data_type       => { is_foreign_key => 1, source => 'NumberType' },
    semantics       => { html_input => 'textarea', rows => 10, cols => 20 },
    unit            => { is_foreign_key => 1, source => 'Unit' },
    style           => { is_foreign_key => 1, source => 'Style', is_part => 1 },
    driver          => { data_type => 'text', html_size => 40 },
    subset          => { data_type => 'text', html_size => 40 },
    epsg            => { data_type => 'integer' },
    bbox            => { data_type => 'text', html_size => 40 },
    band            => { data_type => 'integer' },
    );

__PACKAGE__->table('datasets');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(custodian => 'SmartSea::Schema::Result::Organization');
__PACKAGE__->belongs_to(data_model => 'SmartSea::Schema::Result::DataModel');
__PACKAGE__->belongs_to(is_a_part_of => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(is_derived_from => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(license => 'SmartSea::Schema::Result::License');
__PACKAGE__->belongs_to(data_type => 'SmartSea::Schema::Result::NumberType');
__PACKAGE__->belongs_to(unit => 'SmartSea::Schema::Result::Unit');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');

__PACKAGE__->has_many(parts => 'SmartSea::Schema::Result::Dataset', 'is_a_part_of');
__PACKAGE__->has_many(derivatives => 'SmartSea::Schema::Result::Dataset', 'is_derived_from');

sub classes {
    my $self = shift;
    return unless $self->data_type;
    if ($self->data_type->id == INTEGER_NUMBER) { # integer
        my $min = $self->min_value // 0;
        my $max = $self->max_value // 1;
        my $n = $max - $min + 1;
        $n = 101 if $n > 101;
        return $n;
    } else {
        return 101;
    }
}

sub semantics_hash {
    my $self = shift;
    if (defined $self->semantics) {
        my %semantics;
        for my $item (split /;/, $self->semantics) {
            say STDERR "Bad semantics item $item in dataset ".$self->id unless $item =~ /=/;
            my ($value, $meaning) = split /=/, $item;
            $value = 0 unless $value;
            $meaning //= '';
            $value =~ s/^\D+//;
            $value =~ s/\D+$//;
            $meaning =~ s/^\s+//;
            $meaning =~ s/\s+$//;
            $semantics{$value+0} = $meaning;
        }
        return \%semantics;
    }
    return undef;
}

sub relationship_hash {
    return {
        parts => {
            name => 'Subdataset',
            source => 'Dataset',
            ref_to_parent => 'is_a_part_of',
            set_to_null => 'is_derived_from',
            parent_is_parent => 0,
            class_widget => sub {
                my ($self, $children) = @_;
                return hidden(is_a_part_of => $self->{row}->id);
            }
        },
        derivatives => {
            name => 'Derivative dataset',
            source => 'Dataset',
            ref_to_parent => 'is_derived_from',
            set_to_null => 'is_a_part_of',
            parent_is_parent => 0,
            class_widget => sub {
                my ($self, $children) = @_;
                return hidden(is_derived_from => $self->{row}->id);
            }
        }
    };
}

sub lineage {
    my $self = shift;
    my $lineage = $self->name;
    $lineage .= ' (is a part of) '.$self->is_a_part_of->name if $self->is_a_part_of;
    $lineage .= ' (is derived from) '.$self->is_derived_from->name if $self->is_derived_from;
    return $lineage;
}

sub usable_in_rule {
    my $self = shift;
    return $self->data_type && defined $self->min_value && defined $self->max_value;
}

sub my_unit {
    my $self = shift;
    return $self->unit if defined $self->unit;
    return $self->is_a_part_of->my_unit if defined $self->is_a_part_of;
    return $self->is_derived_from->my_unit if defined $self->is_derived_from;
    return undef;
}

sub parse_gdalinfo {
    my ($info, $args) = @_;
    my %parsed;
    for (@$info) {
        #Band 1 Block=18520x1 Type=Byte, ColorInterp=Gray
        if (/Type=(\w+)/) {
            $parsed{type} = $1;
        }
        #    Computed Min/Max=1.000,1.000
        if (/Min\/Max=([\-\d.]+),([\-\d.]+)/) {
            $parsed{min_value} = $1;
            $parsed{max_value} = $2;
            next;
        }
        #  Min=0.000 Max=1.000 
        if (/Min=([\-\d.]+)/) {
            $parsed{min_value} = $1;
        }
        if (/Max=([\-\d.]+)/) {
            $parsed{max_value} = $1;
        }
    }
    if (defined $parsed{type}) {
        if ($parsed{type} =~ /Byte/ or $parsed{type} =~ /Int/) {
            $parsed{data_type} = INTEGER_NUMBER;
        } elsif ($parsed{type} =~ /Float/) {
            $parsed{data_type} = REAL_NUMBER;
        }
    }
    delete $parsed{type};
    return \%parsed;
}

sub gdal_dataset_name {
    my ($self, $args) = @_;
    my $path = $args->{parameters}{path};
    if (ref $self) {
        if (defined $args->{parameters}{path}) {
            $self->path($path);
        } else {
            $path = $self->path;
        }
    }
    return unless $path;
    my $driver = $args->{parameters}{driver};
    if (ref $self) {
        if (defined $args->{parameters}{driver}) {
            $self->driver($driver);
        } else {
            $driver = $self->driver;
        }
    }
    $driver //= '';
    my $subset = $args->{parameters}{subset};
    if (ref $self) {
        if (defined $args->{parameters}{subset}) {
            $self->subset($subset);
        } else {
            $subset = $self->subset;
        }
    }
    if ($driver eq 'PG') {
        $path = "$path.$subset";
        my $so = 'PG:"dbname='.$args->{dbname}.' user='.$args->{db_user}.' password='.$args->{db_passwd}.'"';
        $path = "-so $so '$path'";
    } elsif ($driver eq 'WMS') {
        $path = $args->{data_dir}.$path;
    } elsif ($driver eq 'NETCDF') {
        $path = 'NETCDF:'.$args->{data_dir}.$path;
        $path .= ':'.$subset if $subset;
    } else {
        $path = $args->{data_dir}.$path;
    }
    return $path;
}

sub auto_fill_cols {
    my ($self, $args) = @_;
    my $driver = $self->driver // '';
    return if $driver eq 'PG' || $driver eq 'WMS';
    my $path = $self->gdal_dataset_name($args);
    say STDERR "autofill from $path" if $args->{debug};
    my @info = `gdalinfo $path`;
    my $parsed = parse_gdalinfo(\@info, $args);
    my %col = @columns;
    for my $key (sort keys %$parsed) {
        my $value = $self->$key;
        say STDERR "$key = $parsed->{$key}, value = $value" if $args->{debug} > 1;
        if (defined($value) && defined($parsed->{$key})) {
            my $comp;
            if (data_type_is_numeric($col{$key}{data_type})) {
                $comp = $value == $parsed->{$key};
            } elsif ($col{$key}{is_foreign_key}) {
                $comp = $value->id == $parsed->{$key};
            } else {
                $comp = $value eq $parsed->{$key};
            }
            $self->$key($parsed->{$key}) if !$comp;
        } else {
            $self->$key($parsed->{$key}) if defined($value) || defined($parsed->{$key});
        }
    }
}

sub compute_cols {
    my ($self, $args) = @_;
    my $driver = $self->driver // '';
    return if $driver eq 'PG' || $driver eq 'WMS';
    my $path = $self->gdal_dataset_name($args);
    say STDERR "compute cols from $path"if $args->{debug};
    my @info = `gdalinfo -mm $path`;
    my $parsed = parse_gdalinfo(\@info, $args);
    my %col = @columns;
    for my $key (sort keys %$parsed) {
        say STDERR "$key = $parsed->{$key}" if $args->{debug} > 1;
        if (ref $self) {
            my $value = $self->$key;
            if (defined($value) && defined($parsed->{$key})) {
                my $comp;
                if (data_type_is_numeric($col{$key}{data_type})) {
                    $comp = $value == $parsed->{$key};
                } elsif ($col{$key}{is_foreign_key}) {
                    $comp = $value->id == $parsed->{$key};
                } else {
                    $comp = $value eq $parsed->{$key};
                }
                $self->$key($parsed->{$key}) if !$comp;
            } else {
                $self->$key($parsed->{$key}) if defined($value) || defined($parsed->{$key});
            }
        } else {
            $args->{parameters}->set($key => $parsed->{$key}) if defined $parsed->{$key};
        }
    }
}

sub info {
    my ($self, $args) = @_;
    my $path = $self->path;
    return unless $path;
    $path = $self->gdal_dataset_name($args);
    say STDERR $path;
    
    my $driver = $self->driver // '';
    my $info = '';
    if ($driver eq 'PG') {
        $info = `ogrinfo $path`;
        $info =~ s/user=(.*?) /user=xxx /;
        $info =~ s/password=(.*)/password=xxx/;
        
    } else {    
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

sub read {
    my ($self) = @_;
    my $data_type = $self->data_type;
    my $palette;
    my $args = {
        min => $self->min_value,
        max => $self->max_value,
        data_type => $data_type ? $data_type->id : undef,
    };
    $self->style->prepare($args) if $self->style;
    # make sure numbers are numbers for JSON
    my $min = $self->min_value;
    $min += 0 if defined $min;
    my $max = $self->max_value;
    $max += 0 if defined $max;
    my %dataset = (
        id => $self->id,
        use_id => 0, # reserved use id
        use_class_id => 0, # reserved use class id
        name => $self->name,
        descr => $self->descr,
        provenance => $self->lineage,
        style => $self->style ? {
          palette => $self->style->palette->name,
          min => $self->style->min,
          max => $self->style->max,
        } : 'grayscale',
        min_value => $min,
        max_value => $max,
        classes => $self->style ? $self->style->classes : undef,
        data_type => $data_type ? $data_type->name : undef,
        semantics => $self->semantics_hash,
        owner => 'system'
        );
    return \%dataset;
}

sub Band {
    my ($self, $args) = @_;

    my $path = $self->path;
    my $tile = $args->{tile};
    my $driver = $self->driver // '';
    my $epsg = $self->epsg // 3067;
    my $band = $self->band // 1;

    if ($driver eq 'PG') {
        # path is Schema, subset is table
        
        my ($w, $h) = $tile->size;
        my $ds = Geo::GDAL::Driver('GTiff')->Create(Name => "/vsimem/r.tiff", Width => $w, Height => $h);
        my ($minx, $maxy, $maxx, $miny) = $tile->projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);        
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>$args->{epsg}));

        my $table = $self->subset // '';
        $path = "\"$path\".\"$table\"";
        my $sql = "select gid,st_transform(geom,$args->{epsg}) as geom from $path";
        $args->{GDALVectorDataset}->Rasterize($ds, [-burn => 1, -sql => $sql]);
        
        return $ds->Band;

    }

    if ($driver eq 'WMS') {
        # download a suitable piece of the data
        my @projwin; # xmin, ymax, xmax, ymin
        my @outsize = (undef, 300); # w h
        
        my @extent = @{$tile->extent}; # minx miny maxx maxy 
        
        if ($epsg != $args->{epsg}) {
            my $src = Geo::OSR::SpatialReference->new(EPSG => $args->{epsg});
            my $dst = Geo::OSR::SpatialReference->new(EPSG => $self->epsg);
            my $ct = Geo::OSR::CoordinateTransformation->new($src, $dst);
            my $ll = $ct->TransformPoint(@extent[0..1]);
            my $tr = $ct->TransformPoint(@extent[2..3]);
            
            $projwin[0] = $ll->[0] > $tr->[0] ? $tr->[0] : $ll->[0];
            $projwin[2] = $ll->[0] < $tr->[0] ? $tr->[0] : $ll->[0];
            $projwin[3] = $ll->[1] > $tr->[1] ? $tr->[1] : $ll->[1];
            $projwin[1] = $ll->[1] < $tr->[1] ? $tr->[1] : $ll->[1];
        } else {
            $projwin[0] = $extent[0];
            $projwin[1] = $extent[3];
            $projwin[2] = $extent[2];
            $projwin[3] = $extent[1];
        }
        
        my $k = ($projwin[2] - $projwin[0]) / ($projwin[1] - $projwin[3]);
        $outsize[0] = POSIX::lround($outsize[1] * $k);
        
        say STDERR "-projwin @projwin -outsize @outsize" if $args->{debug} > 1;
        my $jpeg = "/vsimem/wms.jpeg";
        
        Geo::GDAL::Open("$args->{data_dir}$path")
            ->Translate( $jpeg,
                         [ -of => 'JPEG',
                           -r => 'nearest',
                           -outsize => @outsize,
                           -projwin => @projwin ]);
        $path = $jpeg;
        
    } else {
        
        $path = $self->gdal_dataset_name($args);
        
    }
   
    return Geo::GDAL::Open($path)
        ->Translate( "/vsimem/tmp.tiff", 
                     [ -of => 'GTiff',
                       -r => 'nearest',
                       -outsize => $tile->size,
                       -projwin => $tile->projwin ])
        ->Band($band) if $args->{epsg} == $epsg;
    
    return Geo::GDAL::Open($path)
        ->Warp( "/vsimem/tmp.tiff", 
                [ -of => 'GTiff', 
                  -r => 'near',
                  -s_srs => 'EPSG:'.$epsg,
                  -t_srs => 'EPSG:'.$args->{epsg},
                  -te => @{$tile->extent},
                  -ts => $tile->size ])
        ->Band($band);
}

1;
