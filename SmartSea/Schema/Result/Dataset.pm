package SmartSea::Schema::Result::Dataset;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use Class::Hash ALL_METHODS => 1;
use SmartSea::Schema::Result::DataModel qw(:all);
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
    is_a_part_of    => { is_foreign_key => 1, source => 'Dataset', self_ref => 1 },
    is_derived_from => { is_foreign_key => 1, source => 'Dataset', self_ref => 1 },
    license         => { is_foreign_key => 1, source => 'License' },
    attribution     => { data_type => 'text',    html_size => 40 },
    disclaimer      => { data_type => 'text',    html_size => 80 },
    driver          => { data_type => 'text', html_size => 40, fieldset => 'For GDAL',
                         comment => "PG, NETCDF, WCS, WMS(/AGS), or nothing" },
    data_model      => { is_foreign_key => 1, source => 'DataModel', fieldset => 'For GDAL', 
                         comment => 'To force data model on driver. Not usually needed.' },
    path            => { data_type => 'text',    html_size => 50, fieldset => 'For GDAL',
                         comment => "File path relative to data_dir, schema in main DB, or URL." },
    subset          => { data_type => 'text', html_size => 40, fieldset => 'For GDAL',
                         comment => "NetCDF subset, table in schema, or nothing" },
    epsg            => { data_type => 'integer', fieldset => 'For GDAL',
                         comment => 'Default is 3067.' },
    bbox            => { data_type => 'text', html_size => 40, fieldset => 'For GDAL',
                         comment => "For the GDAL WMS description file. Format: UpperLeftX,LowerRightY,LowerRightX,UpperLeftY" },
    wms_size        => { data_type => 'text', html_size => 40, fieldset => 'For GDAL',
                         comment => "For the GDAL WMS description file. Format: SizeX,SizeY" },
    band            => { data_type => 'integer', fieldset => 'For GDAL',
                         comment => 'Default is 1' },
    gid             => { data_type => 'text', fieldset => 'For GDAL',
                         comment => 'PK (for PG datasets).' },
    burn            => { data_type => 'text', fieldset => 'For GDAL',
                         comment => 'Burn column (for PG datasets).' },
    geometry_column => { data_type => 'text', fieldset => 'For GDAL',
                         comment => 'Geometry column (for PG datasets).' },
    where_clause    => { data_type => 'text', html_size => 60, fieldset => 'For GDAL',
                         comment => 'Where clause (for PG datasets).' },
    data_type       => { is_foreign_key => 1, source => 'NumberType', fieldset => 'For rules',
                         comment => "Only for real datasets. (Forcing) boolean means nodata and zero are false (0), others are true (1). Use button 'obtain values'." },
    min_value       => { data_type => 'double',  html_size => 20, fieldset => 'For rules',
                         comment => "Only for real datasets. Use button 'obtain values'." },
    max_value       => { data_type => 'double',  html_size => 20, fieldset => 'For rules',
                         comment => "Only for real datasets. Use button 'obtain values'." },
    semantics       => { html_input => 'textarea', rows => 10, cols => 20, fieldset => 'For rules',
                         comment => "Format: integer_value = bla bla; ..." },
    discretizer     => { data_type => 'double[]', html_size => 40,
                         comment => "Post-processing, to classify a dataset. Implies min_value, max_value, and data_type. Format:{x0,..}" },
    unit            => { is_foreign_key => 1, source => 'Unit',
                         comment => 'For legend.' },
    style           => { is_foreign_key => 1, source => 'Style', is_part => 1,
                         comment => "Required for visualization." },
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

__PACKAGE__->has_many(parts => 'SmartSea::Schema::Result::Dataset', 'is_a_part_of', {order_by => 'name'});
__PACKAGE__->has_many(derivatives => 'SmartSea::Schema::Result::Dataset', 'is_derived_from', {order_by => 'name'});

# return (data_type, min_value, max_value)
sub usable_in_rule {
    my $self = shift;
    return unless $self->data_type;
    return (BOOLEAN) if $self->data_type->id == BOOLEAN;
    my $discretizer = $self->discretizer;
    return (INTEGER_NUMBER, 0, $#$discretizer+1) if $discretizer;
    return unless defined $self->min_value && defined $self->max_value;
    return ($self->data_type, $self->min_value, $self->max_value);
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

sub my_unit {
    my $self = shift;
    return $self->get_column_recursive('unit');
}

sub get_column_recursive {
    my ($self, $column) = @_;
    my $value = $self->$column;
    return $value if defined $value;
    my $up = $self->is_derived_from;
    return $up->get_column_recursive($column) if $up;
    $up = $self->is_a_part_of;
    return $up->get_column_recursive($column) if $up;
    return undef;
}

sub set_column_from_upstream {
    my ($self, $column, $default) = @_;
    return unless ref $self;
    unless (defined $self->$column) {
        my $value = $self->get_column_recursive($column);
        if (defined $value) {
            $self->$column($value);
        } elsif (defined $default) {
            $self->$column($default);
        }
    }
}

sub set_dataset_name_columns {
    my ($self) = @_;
    $self->set_column_from_upstream('driver');
    $self->set_column_from_upstream('data_model');
    $self->set_column_from_upstream('path');
    $self->set_column_from_upstream('subset');
    $self->set_column_from_upstream(band => 1);
    $self->set_column_from_upstream(epsg => 3067);
}

sub gdal_object { # Band or Layer
    my ($self, $options) = @_;
    return unless ref $self && $self->path;

    my $args = $options->{args};
    my $projwin = $options->{projwin};
    my $size = $options->{size};
    my $driver = $self->driver // '';

    unless ($driver) {
        my @type = $self->data_model ? (Type => $self->data_model->name) : ();
        my $d = Geo::GDAL::Open(
            Name => $args->{data_dir}.$self->path,
            @type
        );
        return $d->Band($self->band);
    }
    
    if ($driver eq 'PG') {

        unless ($projwin) {
            my $d = Geo::GDAL::Open(
                Name => 'PG:"dbname='.$args->{db_name}
                . ' user='.$args->{db_user}
                . ' password='.$args->{db_passwd}.'"',
                Type => $self->data_model
                );
            return $d->GetLayer($self->subset); # to do: rasters in postgis db
        }

        my ($w, $h) = @$size;
        my $ds = Geo::GDAL::Driver('GTiff')->Create(
            Name => "/vsimem/r.tiff", 
            Width => $w, 
            Height => $h
            );
        my ($minx, $maxy, $maxx, $miny) = @$projwin;
        $ds->GeoTransform($minx, ($maxx-$minx)/$w, 0, $maxy, 0, ($miny-$maxy)/$h);        
        $ds->SpatialReference(Geo::OSR::SpatialReference->new(EPSG=>$args->{epsg}));
        $ds->Band->NoDataValue(0);

        # path is Schema, subset is table
        
        my $table = $self->subset // '';
        my $path = $self->path;
        $path = "\"$path\".\"$table\"";
        my $gid = $self->gid // 'gid';
        my $burn = $self->burn;
        my $burn_col = $burn ? ",$burn" : '';
        my $geom = $self->geometry_column // 'geom';
        my $where = $self->where_clause // '';
        $where = "where $where" if $where;
        my $sql = "select $gid$burn_col,st_transform($geom,$args->{epsg}) as geom from $path $where";
        my @arg = (-sql => $sql);
        if ($burn) {
            push @arg, (-a => $burn);
        } else {
            push @arg, (-burn => 1);
        }
        $args->{GDALVectorDataset}->Rasterize($ds, \@arg);
        
        return $ds->Band;
        
    }

    if ($driver eq 'WCS') {

        my $xml = Geo::OGC::Service::XMLWriter::Caching->new([], '');
        $xml->element(WCS_GDAL => 
            [ServiceURL => $self->path.'?'],
            [CoverageName => $self->subset]
        );
        my $name = '/vsimem/wcs.xml';
        my $f = Geo::GDAL::VSIF::Open($name, 'w');
        $f->Write($xml->to_string);
        $f->Close;
        my $dataset = Geo::GDAL::Open(Name => $name);
        return $dataset->Band($self->band) unless $projwin;
        return $dataset
            ->Translate('/vsimem/wcs.tiff', [
                            -of => 'GTiff',
                            -r => 'nearest',
                            -outsize => @$size,
                            -projwin => @$projwin])
            ->Band($self->band);
    }

    if ($driver =~ /WMS/) {
        # does not really make sense

        my $xml = Geo::OGC::Service::XMLWriter::Caching->new([], '');
        
        if ($driver =~ /AGS/) {

            my $path = $self->path;
            my $service = [
                [ServerUrl => "http://paikkatieto.ymparisto.fi/arcgis/rest/services/$path/MapServer"],
                [BBoxOrder => 'xyXY'],
                [SRS => 3067],
                [Transparent => 'TRUE'],
                [Layers => 'show%3A' . $self->subset]
            ];
            my $data_window = [
                [UpperLeftX => $projwin->[0]],
                [UpperLeftY => $projwin->[1]],
                [LowerRightX => $projwin->[2]],
                [LowerRightY => $projwin->[3]],
                [SizeX => $size->[0]],
                [SizeY => $size->[1]]
            ];
            
            $xml->element(GDAL_WMS => 
                [Service => {name => 'AGS'}, $service],
                [DataWindow => $data_window]
            );
            
        } else {

            my $service = [
                [Version => '1.1.1'],
                [ServerUrl => $self->path],
                [SRS => 'EPSG:'.$self->epsg],
                [ImageFormat => 'image/jpeg'],
                [Transparent => 'FALSE'],
                [Layers => $self->subset],
                ];

            my @bbox = split(/,/, $self->bbox);
            my @size = split(/,/, $self->wms_size);
            my $data_window = [
                [UpperLeftX => $bbox[0]],
                [UpperLeftY => $bbox[3]],
                [LowerRightX => $bbox[2]],
                [LowerRightY => $bbox[1]],
                [SizeX => $size[0]],
                [SizeY => $size[1]],
                ];

            $xml->element(GDAL_WMS =>
                [Service => {name => "WMS"}, $service],
                [DataWindow => $data_window],
                [BandsCount => 3],
                [DataType => 'Byte'],
                [BlockSizeX => 1024],
                [BlockSizeY => 1024],
            );

        }

        say STDERR $xml->to_string if $args->{debug} > 2;
        
        my $name = '/vsimem/wms.xml';
        my $f = Geo::GDAL::VSIF::Open($name, 'w');
        $f->Write($xml->to_string);
        $f->Close;

        my $dataset = Geo::GDAL::Open(Name => $name);
        return $dataset->Band($self->band) unless $projwin;
        return $dataset
            ->Translate('/vsimem/wms.tiff', [
                            -a_nodata => 253,
                            -of => 'GTiff',
                            -r => 'nearest',
                            -outsize => @$size,
                            -projwin => @$projwin ])
            ->Band($self->band);
        
    }

    if ($driver  eq 'NETCDF') {
        my $name = 'NETCDF:'.$args->{data_dir}.$self->path;
        $name .= ':'.$self->subset if $self->subset;
        my $d = Geo::GDAL::Open(
            Name => $name
        );
        return $d->Band($self->band);
    }
    
}

sub compute_cols {
    my ($self, $args) = @_;
    unless (ref $self) {
        $self = Class::Hash->new;
        for my $col (qw/driver data_model path subset band epsg/) {
            $self->{$col} = $args->{parameters}{$col} if $args->{parameters}{$col} ne '';
        }
    } else {
        $self->set_dataset_name_columns;
    }
    my $gdal = gdal_object($self, {
        args => $args,
        #size => [],
        #projwin => []
    });
    return unless $gdal;
    return unless ref $gdal eq 'Geo::GDAL::Band';
    $gdal->ComputeStatistics(0) unless $gdal->Dataset->Driver->Name =~ /^W/;
    my $msg = [];
    for my $col (qw/min_value max_value data_type epsg/) { # bbox
        #next if defined $self->$col;
        #next if defined $args->{parameters}{$col};
        my $value;
        if ($col eq 'min_value') {
            $value = $gdal->GetMinimum;
        } elsif ($col eq 'max_value') {
            $value = $gdal->GetMaximum;
        } elsif ($col eq 'data_type') {
            $value = $gdal->DataType;
            if ($value eq 'Byte' or $value =~ /^U?I/) {
                $value = INTEGER_NUMBER;
            } elsif ($value =~ /^F/) {
                $value = REAL_NUMBER;
            } else {
                undef $value;
            }
        } elsif ($col eq 'epsg') {
            my $srs = $gdal->Dataset->SpatialReference;
            if ($srs) {
                eval {
                    $value = $srs->AutoIdentifyEPSG;
                };
                push @$msg, 
                [1 => 'EPSG autoidentification failed. This is the WKT.'],
                [pre => $srs->As('PrettyWKT')] if $@;
            }
        }
        #$self->$col($value) if defined $value;
        $args->{parameters}{$col} = $value if defined $value;
    }
    return $msg;
}

sub info {
    my ($self, $args) = @_;
    $self->set_dataset_name_columns;
    return 'Not a real dataset.' unless $self->path;
    my $gdal;
    eval {
        $gdal = $self->gdal_object({
            args => $args
        });
    };
    my $err = '';
    if ($@) {
        my @err = split "\n", $@;
        $err = shift @err;
    }
    my $info = $gdal ? 'GDAL dataset open successful.' : "Not a real dataset. ($err)";
    if ($gdal) {
        if ($self->usable_in_rule) {
            $info .= ' This dataset can be used in rules.';
        }
    }
    return $info;
}

sub read {
    my ($self) = @_;
    my ($data_type, $min_value, $max_value) = $self->usable_in_rule;
    return unless $data_type;
    
    $self->style->prepare({
        data_type => $data_type,
        min => $min_value,
        max => $max_value,
    }) if $self->style;

    my $default_palette = 'grayscale';

    my @minmax;
    my %style;

    if ($data_type == BOOLEAN) {
        @minmax = (data_type => 'boolean');
        %style = (
            palette => $self->style ? 
            $self->style->palette->name : 
            $default_palette
            );
    } else {
        # make sure numbers are numbers for JSON
        my $min = $self->min_value;
        $min += 0 if defined $min;
        my $max = $self->max_value;
        $max += 0 if defined $max;
        @minmax = (
            data_type => $data_type == INTEGER_NUMBER ? 'integer' : 'real',
            min_value => $min,
            max_value => $max
            );
        push @minmax, (semantics => $self->semantics_hash) if $self->semantics;
        if ($self->style) {
            %style = (
                palette => $self->style->palette->name,
                min => $self->style->min,
                max => $self->style->max,
                );
        } else {
            %style = (
                palette => $default_palette,
                min => $min,
                max => $max,
                );
        }
    }    
    return {
        id => $self->id,
        name => $self->name,
        descr => $self->descr,
        provenance => $self->lineage,
        style => \%style,
        @minmax,
        owner => 'system'
    };
}

sub Band {
    my ($self, $args) = @_;

    $self->set_dataset_name_columns;
    my $driver = $self->driver // '';
    my $tile = $args->{tile};    
    my $band;
    my $ready;

    unless ($driver) {

        # just open the dataset/band
        $band = Geo::GDAL::Open(Name => $args->{data_dir}.$self->path)->Band($self->band);

    } elsif ($driver eq 'PG') {

        # rasterize into target size, bbox & projection
        $band = $self->gdal_object({
            args => $args,
            projwin => [$tile->projwin],
            size => [$tile->size]
        });
        $ready = 1;
        
    } elsif ($driver =~ /^W/) {

        # download a suitable piece of the data
        # it will be in its native projection
        my $projwin = $self->compute_projwin($args);
        my $k = ($projwin->[2] - $projwin->[0]) / ($projwin->[1] - $projwin->[3]);
        my @size = (POSIX::lround(300 * $k), 300); # w h

        $band = $self->gdal_object({
            args => $args,
            projwin => $projwin,
            size => \@size
        });
        
    }

    unless ($ready) {
        if ($self->epsg == $args->{epsg}) {
            $band = $band
                ->Dataset
                ->Translate("/vsimem/tmp.tiff", [ 
                                -of => 'GTiff',
                                -r => 'nearest',
                                -outsize => $tile->size,
                                -projwin => $tile->projwin ])
                ->Band($self->band);
        } else {
            $band = $band
                ->Dataset
                ->Warp("/vsimem/tmp.tiff", [ 
                           -of => 'GTiff', 
                           -r => 'near',
                           -s_srs => 'EPSG:'.$self->epsg,
                           -t_srs => 'EPSG:'.$args->{epsg},
                           -te => @{$tile->extent},
                           -ts => $tile->size ])
                ->Band($self->band);
        }
    }
    
    my $discretizer = $self->discretizer;        
    if ($discretizer) {
        my $classifier = ['<='];
        my $tree = [$discretizer->[0], 0, 1];
        for my $i (1 .. $#$discretizer) {
            $tree = [$discretizer->[$i], [@$tree], $i+1];
        }
        push @$classifier, $tree;
        $band->Reclassify($classifier);
    }
    
    return $band;
}

sub compute_projwin {
    my ($self, $args) = @_;
    my @projwin; # xmin, ymax, xmax, ymin
    my @extent = @{$args->{tile}->extent}; # minx miny maxx maxy 
    if ($self->epsg != $args->{epsg}) {
        my $src = Geo::OSR::SpatialReference->new(EPSG => $args->{epsg});
        my $dst = Geo::OSR::SpatialReference->new(EPSG => $self->epsg);
        my $ct = Geo::OSR::CoordinateTransformation->new($src, $dst);
        
        my $nn = $ct->TransformPoint(@extent[0,1]);
        my $nx = $ct->TransformPoint(@extent[0,3]);
        my $xn = $ct->TransformPoint(@extent[2,1]);
        my $xx = $ct->TransformPoint(@extent[2,3]);
        
        $projwin[0] = $nn->[0] < $nx->[0] ? $nn->[0] : $nx->[0];
        $projwin[1] = $nx->[1] < $xx->[1] ? $xx->[1] : $nx->[1];
        $projwin[2] = $xn->[0] < $xx->[0] ? $xx->[0] : $xn->[0];
        $projwin[3] = $nn->[1] < $xn->[1] ? $nn->[1] : $xn->[1];
    } else {
        $projwin[0] = $extent[0];
        $projwin[1] = $extent[3];
        $projwin[2] = $extent[2];
        $projwin[3] = $extent[1];
    }
    return \@projwin;
}

1;
