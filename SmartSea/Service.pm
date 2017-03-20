package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Schema;
use Data::Dumper;
use Data::GUID;
use GD;

use parent qw/Plack::Component/;

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    $self->{data_dir} .= '/' unless $self->{data_dir} =~ /\/$/;
    $self->{images} .= '/' unless $self->{images} =~ /\/$/;
    $self = Plack::Component->new($self);
    my $dsn = "dbi:Pg:dbname=$self->{dbname}";
    $self->{schema} = SmartSea::Schema->connect(
        $dsn, 
        $self->{user}, 
        $self->{pass}, 
        { on_connect_do => ['SET search_path TO tool,data,public'] });
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    my $ret = common_responses({}, $env);
    return $ret if $ret;
    my $user = $env->{REMOTE_USER} // 'guest';
    $self->{edit} = 1 if $user eq 'ajolma';
    say STDERR "remote user is $user";
    my $request = Plack::Request->new($env);
    my $cookies = $request->cookies;
    for my $cookie (sort keys %$cookies) {
        #say STDERR "cookie: $cookie => $cookies->{$cookie}";
    }
    $self->{cookie} = $cookies->{SmartSea} // DEFAULT;
    say STDERR "cookie: $self->{cookie}";
    $self->{parameters} = $request->parameters;
    $self->{uri} = $env->{REQUEST_URI};
    $self->{origin} = $env->{HTTP_ORIGIN};
    for my $key (sort keys %$env) {
        #say STDERR "$key => $env->{$key}";
    }
    my @path = split /\//, $self->{uri};
    say STDERR "path: @path";
    my @base;
    while (@path) {
        my $step =shift @path;
        #say STDERR $step;
        push @base, $step;
        return $self->plans(\@path) if $step eq 'plans';
        return $self->plans(\@path) if $step eq 'layers';
        return $self->impact_network(\@path) if $step eq 'impact_network';
        return $self->pressure_table(\@path) if $step eq 'pressure_table';
        return $self->legend() if $step =~ /^legend/;
        if ($step eq 'browser') {
            $step = shift(@path) // '';
            push @base, $step;
            $self->{base_uri} = join('/', @base);
            my $class = 'SmartSea::Schema::Result::';
            return $self->object_editor($class.'Plan', \@path) if $step eq 'plans';
            return $self->object_editor($class.'Use', \@path) if $step eq 'uses';
            return $self->object_editor($class.'Activity', \@path) if $step eq 'activities';
            return $self->object_editor($class.'Layer', \@path) if $step eq 'layers';
            return $self->object_editor($class.'Rule', \@path) if $step eq 'rules';
            return $self->object_editor($class.'Dataset', \@path) if $step eq 'datasets';
            return $self->object_editor($class.'Pressure', \@path) if $step eq 'pressures';
            return $self->object_editor($class.'Impact', \@path) if $step eq 'impacts';
            return $self->object_editor($class.'EcosystemComponent', \@path) if $step eq 'ecosystem_components';
            last;
        }
    }
    @path = split /\//, $self->{uri};
    my $uri = '';
    for my $step (@path) {
        $uri .= "$step/";
        last if $step eq 'core' or $step eq 'core_auth';
    }
    my @l;
    push @l, (
        [li => a(link => 'plans', url  => $uri.'plans')],
        [li => a(link => 'layers', url  => $uri.'layers')],
        [li => [0 => 'browsers']],
        [ul => [
             [li => a(link => 'plans', url => $uri.'browser/plans')],
             [li => a(link => 'uses', url => $uri.'browser/uses')],
             [li => a(link => 'activities', url => $uri.'browser/activities')],
             [li => a(link => 'layers', url => $uri.'browser/layers')],
             [li => a(link => 'datasets', url  => $uri.'browser/datasets')],
             [li => a(link => 'pressures', url  => $uri.'browser/pressures')],
             [li => a(link => 'impacts', url  => $uri.'browser/impacts')],
             [li => a(link => 'ecosystem components', url => $uri.'browser/ecosystem_components')]
         ]
        ],
        [li => a(link => 'impact_network', url  => $uri.'impact_network')],
        [li => a(link => 'pressure table', url  => $uri.'pressure_table')]
    );
    return html200({}, SmartSea::HTML->new(html => [body => [ul => \@l]])->html);
}

sub legend {
    my ($self, $oids) = @_;

    my %header;
    $header{'Content-Type'} //= 'image/png';
    $header{'Access-Control-Allow-Origin'} //= '*';

    my $layer = SmartSea::Layer->new({
        schema => $self->{schema},
        trail => $self->{parameters}{layer}});

    unless ($layer->{duck}) {
        my $image = GD::Image->new('/usr/share/icons/cab_view.png');
        return [ 200, [%header], [$image->png] ];
    }
    
    my ($min, $max, $unit) = $layer->range();

    my $fontHeight = 12;
    my $halfFontHeight = $fontHeight/2;
    my $imageWidth = 200; # layout.css.right.width
    my $colorWidth = 50;
    my $colorHeight = 128;
    my $imageHeight = $colorHeight+$fontHeight;
    
    my $image = GD::Image->new($imageWidth, $imageHeight);
    
    my $color = $image->colorAllocateAlpha(255,255,255,0);
    $image->filledRectangle($colorWidth,0,99,$imageHeight-1+$fontHeight,$color);
    for my $y (0..$halfFontHeight-1) {
        $image->line(0,$y,$colorWidth-1,$y,$color);
    }

    my $nc = $layer->classes;
    for my $y (0..$colorHeight-1) {
        my $i = $nc-1 - int($y/($colorHeight-1)*($nc-1)+0.5);
        my $color = $image->colorAllocateAlpha($layer->color($i));
        $image->line(0, $y+$halfFontHeight, $colorWidth-1, $y+$halfFontHeight, $color);
    }
    for my $y ($imageHeight-$halfFontHeight+1..$imageHeight-1) {
        $image->line(0, $y, $colorWidth-1, $y, $color);
    }
    
    $color = $image->colorAllocateAlpha(0,0,0,0);
    my $font = gdMediumBoldFont;
    $font = GD::Font->load($self->{images}.'/X_9x15_LE.gdf');

    unless (defined $nc) {
        # this is for continuous data; never happens??
        $image->string($font, $colorWidth, -1, "- $max$unit", $color);
        $image->string($font, $colorWidth, $imageHeight-$fontHeight-2, "- $min$unit", $color);
    } else {
        my $step = int($nc/($colorHeight/$fontHeight)+0.5);
        $step = 1 if $step < 1;
        my $d = $layer->descr // '';
        my $c = $nc == 1 ? 0 : ($max - $min) / ($nc - 1);
        for (my $class = 1; $class <= $nc; $class += $step) {
            my $y;
            if ($nc == 1) {
                $y = int($colorHeight / 2);
            } elsif ($nc == 2) {
                $y = int((1 - ($class-0.5)/$nc)*($colorHeight-1));
            } else {
                my $n = $nc - 1;
                my $m = 0.25;
                $m += 0.75 if $class > 1;
                $m += $class-2 if $class > 2;
                $m -= 0.25 if $class == $nc;
                $y = int((1 - $m/$n)*($colorHeight-1));
            }
            my $l;
            my ($l2) = $d =~ /$class = ([\w, \-]+)/;
            if ($l2) {
                $l = $l2;
            } elsif (defined $min) {
                $l = sprintf("%.1f", $min + $c*($class-1)) . $unit;
            } else {
                $l = $class;
            }
            $image->string($font, $colorWidth, $y-1, "- $l", $color);
        }
    }
    
    return [ 200, [%header], [$image->png] ];
}

sub plans {
    my ($self, $oids) = @_;
    say STDERR "@$oids";
    my @ids = split(/_/, shift @$oids // '');
    my $plan_id = shift @ids;
    my $use_id = shift @ids;
    my $layer_id = shift @ids;
    my $schema = $self->{schema};
    my @plans;
    my $search = defined $plan_id ? {id => $plan_id}: undef;
    for my $plan ($schema->resultset('Plan')->search($search, {order_by => {-desc => 'name'}})) {
        my @uses;
        $search = defined $use_id ? {use => $use_id}: undef;
        for my $use ($plan->uses($search, {order_by => 'id'})) {
            my $plan2use = $self->{schema}->
                resultset('Plan2Use')->
                single({plan => $plan->id, use => $use->id});
            my @layers;
            $search = defined $layer_id ? {layer => $layer_id}: undef;
            for my $layer_class ($plan2use->layer_classes($search, {order_by => {-desc => 'id'}})) {
                my $layer = $self->{schema}->
                    resultset('Layer')->
                    single({plan2use => $plan2use->id, layer_class => $layer_class->id});
                my @rules;
                for my $rule ($layer->rules(
                                  {
                                      cookie => DEFAULT
                                  },
                                  {
                                      order_by => { -asc => 'my_index' }
                                  })) {
                    push @rules, $rule->as_hashref_for_json
                }
                push @layers, {
                    name => $layer->layer_class->name,
                    style => $layer->style2->color_scale->name,
                    id => $layer->layer_class->id, 
                    use => $use->id, 
                    rules => \@rules};
            }
            push @uses, {name => $use->name, id => $use->id, plan => $plan->id, layers => \@layers};
        }
        push @plans, {name => $plan->name, id => $plan->id, uses => \@uses};
    }
    if (!defined $plan_id || $plan_id == 0) {
        # make a "plan" from all real datasets
        my @datasets;
        for my $dataset ($schema->resultset('Dataset')->search(
                             undef, 
                             {order_by => {-desc => 'name'}})->all) 
        {
            next unless $dataset->path;
            next if defined $layer_id && $dataset->id != $layer_id;
            my $range = '';
            if (defined $dataset->style2->min) {
                my $u = '';
                $u = ' '.$dataset->my_unit->name if $dataset->my_unit;
                $range = ' ('.$dataset->style2->min."$u..".$dataset->style2->max."$u)";
            }
            push @datasets, {
                name => $dataset->name, 
                descr => $dataset->lineage,
                style => $dataset->style2->color_scale->name.$range,
                id => $dataset->id, 
                use => 0, 
                rules => []};
        }
        push @plans, { 
            name => 'Data', 
            id => 0, 
            uses => [{name => 'Data', id => 0, plan => 0, layers => \@datasets}]};
    }
    #print STDERR Dumper \@plans;

    # This is the first request made by the App, thus set the cookie
    # if there is not one. The cookie is only for the duration the
    # browser is open.

    my $header = {
        'Access-Control-Allow-Origin' => $self->{origin},
        'Access-Control-Allow-Credentials' => 'true'
    };
    if ($self->{cookie} eq DEFAULT) {
        my $guid = Data::GUID->new;
        my $cookie = $guid->as_string;
        $header->{'Set-Cookie'} = "SmartSea=$cookie; httponly; Path=/";
    } else {

        # Cookie already set, reset changes, i.e., delete temporary
        # rules.  Above we give the default ones, this makes sure
        # temporary ones are not used for WMTS. Note that the rules
        # are left in the table and should be cleaned regularly based
        # on the "made" column.

        eval {
            for my $rule ($schema->resultset('Rule')->search({ cookie => $self->{cookie} })) {
                $rule->delete;
            }
        };
        say STDERR 'Error: '.$@ if $@;

    }
    return json200($header, \@plans);
}

sub impact_network {
    my $self = shift;

    my %elements = (nodes => [], edges => []);

    for my $activity ($self->{schema}->resultset('Activity')->all) {
        push @{$elements{nodes}}, { data => { id => 'a'.$activity->id, name => $activity->name }};
        for my $pressure ($activity->pressures) {
            push @{$elements{edges}}, { data => { 
                source => 'a'.$activity->id, 
                target => 'p'.$pressure->id }};
            my $ap = $self->{schema}->resultset('Activity2Pressure')->
                single({activity => $activity->id, pressure => $pressure->id});
            for my $impacts ($ap->impacts) {
            }
        }
    }
    for my $pressure ($self->{schema}->resultset('Pressure')->all) {
        push @{$elements{nodes}}, { data => { id => 'p'.$pressure->id, name => $pressure->name }};
    }

    return json200({}, \%elements);
}

sub object_editor {
    my ($self, $class, $oids) = @_;

    # oids is what's after the base in URI, 
    # a list of object ids separated by / and possibly /new or ?edit in the end
    # DBIx Class understands undef as NULL
    # config: delete => value-in-the-delete-button (default is Delete)
    #         store => value-in-the-store-button (default is Store)
    #         empty_is_null => parameters will be converted to undef if empty strings
    #         defaults => parameters will be set to the value unless in self->parameters
    # 'NULL' parameters will be converted to undef, 

    say STDERR "uri=$self->{uri}, class=$class, oids=(@$oids)";

    my $config = {};
    $config->{create} //= 'Create';
    $config->{add} //= 'Add';
    $config->{delete} //= 'Delete';
    $config->{remove} //= 'Remove';
    $config->{store} //= 'Store';
    $config->{modify} //= 'Modify';
    $config->{update} //= 'Update';

    my %parameters; # <request> => what, key => value
   
    if (@$oids && $oids->[$#$oids] =~ /([a-z]+)$/) {
        $parameters{request} = $1;
        if ($oids->[$#$oids] =~ /\?/) {
            $oids->[$#$oids] =~ s/\?([a-z]+)$//;
        } else {
            pop @$oids;
        }
    }
    
    # $self->{parameters} is a multivalue hash
    # we may have both object => command and object => id
    for my $key (sort keys %{$self->{parameters}}) {
        for my $value ($self->{parameters}->get_all($key)) {
            if ($key eq 'submit' && $value =~ /^Compute/) {
                $parameters{request} = 'edit';
                $parameters{compute} = $value;
                last;
            }
            $value = decode utf8 => $value;
            my $done = 0;
            for my $request (keys %$config) {
                if ($value eq $config->{$request}) {
                    $parameters{request} = $request;
                    if ($request eq 'delete') {
                        $parameters{id} = $key;
                    } else {
                        $parameters{$request} = $key;
                    }
                    $done = 1;
                    last;
                }
            }
            next if $done;
            if ($value eq 'NULL') {
                $parameters{$key} = undef;
            } else {
                $parameters{$key} = $value;
            }
        }
    }
    $parameters{request} //= '';

    for my $p (sort keys %parameters) {
        say STDERR "$p => ".(defined($parameters{$p})?$parameters{$p}:'undef');
    }

    my %args = (parameters => \%parameters);
    for my $key (qw/uri base_uri schema edit dbname user pass data_dir/) {
        $args{$key} = $self->{$key};
    }
    $args{cookie} = DEFAULT;

    my $rs = $self->{schema}->resultset($class =~ /(\w+)$/);
    my @body;
    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };
    if ($parameters{request} eq 'create' and $self->{edit}) {
        eval {
            create($class =~ /(\w+)$/, \%parameters, $self->{schema});
        };
        say STDERR "error: $@" if $@;
        push @body, [0 => $@] if $@;
    } elsif ($parameters{request} eq 'new' and $self->{edit}) {
        my $path = @$oids ? '/'.join('/',@$oids) : '';
        push @body, $class->HTML_form({ action => $args{base_uri}.$path, method => 'POST' }, \%parameters, %args);
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    } elsif ($parameters{request} eq 'delete' and $self->{edit}) {
        $args{oids} = [@$oids, $parameters{id}];
        my $obj = $class->get_object(%args);
        eval {
            $obj->delete;
        };
        if ($@) {
            push @body, [p => 'Error: '.$@];
        }
        return object_div($class, \@body, $oids, %args) if @$oids;
    } elsif ($parameters{request} eq 'modify') {
        return http_status($header, 403) if $self->{cookie} eq DEFAULT; # forbidden 
        $args{oids} = [@$oids];
        $args{cookie} = $self->{cookie};
        my $obj = $class->get_object(%args);
        my $cols = $obj->values;
        $cols->{value} = $parameters{value};
        $cols->{id} = $obj->id;
        $cols->{plan2use2layer} = $obj->plan2use2layer->id;
        $cols->{cookie} = $self->{cookie};
        my $a = ['current_timestamp'];
        $cols->{made} = \$a;
        eval {
            $obj = $rs->update_or_new($cols, {key => 'primary'});
            $obj->insert if !$obj->in_storage;
        };
        say STDERR "error: $@" if $@;
        return http_status($header, 500) if $@;
        return json200($header, {object => $obj->as_hashref_for_json});
    } elsif ($parameters{request} eq 'store' and $self->{edit}) {
        #$args{oids} = [@$oids, $parameters{id}]; # if pop below
        $args{oids} = [@$oids];
        my $obj = $class->get_object(%args);
        return http_status($header, 400) unless $obj;
        eval {
            update($obj, \%parameters);
        };
        say STDERR "error: $@" if $@;
        if ($@) {
            $args{oids} = [@$oids];
            shift @{$args{oids}};
            push @body, (
                [p => 'Error: '.$@],
                $obj->HTML_form({ action => $args{uri}, method => 'POST' }, \%parameters, %args)
            );
            return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
        }
        return object_div($class, \@body, $oids, %args);
    } elsif ($parameters{request} eq 'edit' and $self->{edit}) {
        $args{oids} = [@$oids];
        my $obj = $class->get_object(%args);
        #pop @$oids;
        my $path = @$oids ? '/'.join('/',@$oids) : '';
        push @body, $obj->HTML_form({ action => $args{base_uri}.$path, method => 'POST' }, {}, %args);
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    } elsif (@$oids) {
        return object_div($class, \@body, $oids, %args);
    }
    my $objs;
    my %primary_columns = map {$_ => 1} $class->primary_columns;
    if (not $primary_columns{cookie}) {
        $objs = [$rs->all];
    } else {
        $objs = [$rs->search({cookie => 'default'})]
    }
    my $list = $class->HTML_list($objs, %args, action => 'Delete');
    $list = [form => { action => $args{uri}, method => 'POST' }, $list] if $self->{edit};
    push @body, $list;
    my @path = split /\//, $self->{uri};
    pop @path;
    push @body, ([1 => ' '], a(link => 'up', url => join('/',@path)));
    return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
}

sub object_div {
    my ($class, $body, $oids, %args) = @_;
    $args{oids} = [$oids->[0]];
    my $obj = $class->get_object(%args);
    $args{oids} = [@$oids];
    shift @{$args{oids}};
    my $div = $obj->HTML_div({}, %args);
    $div = [form => { action => $args{uri}, method => 'POST' }, $div] if $args{edit};
    push @$body, $div;
    pop @$oids;
    my $path = @$oids ? '/'.join('/',@$oids) : '';
    push @$body, a(link => 'up', url => $args{base_uri}.$path);
    return html200({}, SmartSea::HTML->new(html => [body => $body])->html);
}

sub pressure_table {
    my ($self, $x) = @_;
    my %edits;
    $edits{aps} = $self->{schema}->resultset('Activity2Pressure');
    $edits{impacts} = $self->{schema}->resultset('Impact');
    my $pressures = $self->{schema}->resultset('Pressure');
    my %id;
    my %pressures;
    my %cats;
    for my $pressure ($pressures->all) {
        $pressures{$pressure->name} = $pressure->order;
        $id{pressures}{$pressure->name} = $pressure->id;
        $cats{$pressure->name} = $pressure->category->name;
    }
    my $activities = $self->{schema}->resultset('Activity');
    my %activities;
    my %name;
    for my $activity ($activities->all) {
        $activities{$activity->name} = $activity->order;
        $id{activities}{$activity->name} = $activity->id;
        $name{$activity->name} = $activity->name.'('.$activity->order.')';
    }
    my $components = $self->{schema}->resultset('EcosystemComponent');
    my %components;
    for my $component ($components->all) {
        $components{$component->name} = $component->order;
        $id{components}{$component->name} = $component->id;
    }

    for my $pressure ($pressures->all) {
        for my $activity ($activities->all) {
            my $key = 'range_'.$pressure->id.'_'.$activity->id;
            $name{$key} = $pressure->name.' '.$activity->name;

            my $ap = $edits{aps}->single({pressure => $pressure->id, activity => $activity->id});
            $name{$pressure->name}{$activity->name} = $activity->name; #.' '.$ap->id if $ap;
        }
    }

    my %attrs;
    my %ranges;
    for my $ap ($edits{aps}->all) {
        $ranges{$ap->pressure->name}{$ap->activity->name} = $ap->range;
        my $key = 'range_'.$ap->pressure->id.'_'.$ap->activity->id;
        $attrs{$key} = $ap->range;
        $id{activity2pressure}{$ap->pressure->name}{$ap->activity->name} = $ap->id;
    }
    my %impacts;
    for my $impact ($edits{impacts}->all) {
        my $ap = $impact->activity2pressure;
        my $p = $ap->pressure;
        my $a = $ap->activity;
        my $e = $impact->ecosystem_component;
        my $name = $p->name.'+'.$a->name.' -> '.$e->name;
        $impacts{$p->name}{$a->name}{$e->name} = [$impact->strength,$impact->belief];
        my $key = 'strength_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->strength;
        $name{$key} = $name;
        $key = 'belief_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->belief;
        $name{$key} = $name;
    }
    
    #for my $key (sort $self->{parameters}->keys) {
    #    say STDERR "$key $self->{parameters}{$key}";
    #}

    my @error = ();

    my $submit = $self->{parameters}{submit} // '';
    if ($submit eq 'Commit') {
        for my $key ($self->{parameters}->keys) {
            next if $key eq 'submit';
            my $value = $self->{parameters}{$key};
            my ($attr, $one, $two) = $key =~ /([a-w]+)_(\d+)_(\d+)/;

            my %single;
            my %params;
            my $edits;
            if ($attr eq 'range') {
                next if $value eq '0';
                %single = (pressure => $one, activity => $two);
                %params = (pressure => $one, activity => $two, $attr => $value);
                $edits = $edits{aps};
            } else {
                next if $value eq '-1';
                %single = (activity2pressure => $one, ecosystem_component => $two);
                %params = (activity2pressure => $one, ecosystem_component => $two, $attr => $value);
                if (!exists($attrs{$key})) {
                    if ($attr eq 'belief') {
                        $params{strength} = 0;
                    } else {
                        $params{belief} = 0;
                    }
                }
                $edits = $edits{impacts};
            }
            #say STDERR "key = $key, value = $value";
            if (exists($attrs{$key})) {
                if ($attrs{$key} ne $value) {
                    say STDERR "change $key from $attrs{$key} to $value";
                    my $obj = $edits->single(\%single);
                    eval {
                        $obj->update(\%params);
                    };
                }
            } else {
                say STDERR "insert $key as $value";
                eval {
                    $edits->create(\%params);
                };
            }

            if ($@) {
                # if not ok, signal error
                push @error, (
                    [p => 'Something went wrong!'], 
                    [p => 'Error is: '.$@]
                );
                undef $@;
            }

        }

        for my $ap ($edits{aps}->all) {
            $ranges{$ap->pressure->name}{$ap->activity->name} = $ap->range;
        }
        for my $impact ($edits{impacts}->all) {
            my $ap = $impact->activity2pressure;
            my $p = $ap->pressure;
            my $a = $ap->activity;
            my $e = $impact->ecosystem_component;
            $impacts{$p->name}{$a->name}{$e->name} = [$impact->strength,$impact->belief];
        }
    }
    
    my @rows;

    my @components = sort {$components{$a} <=> $components{$b}} keys %components;
    my @headers = ();
    my @tr = ([th => {colspan => 3}, '']);
    for my $component (@components) {
        push @tr, [th => {colspan => 2}, $component];
    }
    push @rows, [tr => [@tr]];

    @headers = ('Pressure', 'Activity', 'Range');
    for (@components) {
        push @headers, qw/Impact Belief/;
    }
    @tr = ();
    for my $h (@headers) {
        push @tr, [th => $h];
    }
    push @rows, [tr => [@tr]];

    my $c = 0;
    my $cat = '';
    for my $pressure (sort {$pressures{$a} <=> $pressures{$b}} keys %pressures) {
        next unless $pressures{$pressure};
        my @activities;
        for my $activity (sort {$activities{$a} <=> $activities{$b}} keys %activities) {
            next unless exists $ranges{$pressure}{$activity};
            my $range = $ranges{$pressure}{$activity} // 0;
            next if $range < 0;
            push @activities, $activity;
        }
        my @td = ([td => {rowspan => $#activities+1}, $pressure]);
        for my $activity (@activities) {
            my $color = $c ? '#cccccc' : '#ffffff';
            push @td, [td => {bgcolor=>$color}, $name{$pressure}{$activity}];

            my $idp = $id{pressures}{$pressure};
            my $ida = $id{activities}{$activity};
            my $idap = $id{activity2pressure}{$pressure}{$activity};

            my $range = $ranges{$pressure}{$activity} // 0;
            $range = text_input(
                name => 'range_'.$idp.'_'.$ida,
                size => 1,
                value => $range
                ) if $self->{edit};
            push @td, [td => {bgcolor=>$color}, $range];

            $color = $c ? '#00ffff' : '#ffffff';
            my $color2 = $c ? '#7fffd4' : '#ffffff';

            for my $component (@components) {
                my $idc = $id{components}{$component};
                my $impact = $impacts{$pressure}{$activity}{$component} // [-1,-1];
                $impact = [text_input(
                               name => 'strength_'.$idap.'_'.$idc,
                               size => 1,
                               value => $impact->[0]
                           ),
                           text_input(
                               name => 'belief_'.$idap.'_'.$idc,
                               size => 1,
                               value => $impact->[1]
                           )] if $self->{edit};
                push @td, ([td => {bgcolor=>$color}, $impact->[0]],[td => {bgcolor=>$color2}, $impact->[1]]);
            }

            if ($cat ne $cats{$pressure}) {
                $cat = $cats{$pressure};
                my @c = ([td => $cat]);
                for (1..$#td) {
                    push @c, [td => ''];
                }
                push @rows, [tr => \@c];
            }

            push @rows, [tr => [@td]];
            @td = ();
            $c = !$c; 
        }
    }

    my @a = ([a => {href => $self->{uri}}, 'reload'],
             [1 => "&nbsp;&nbsp;"]);
    push @a, [input => {type => 'submit', name => 'submit', value => 'Commit'}] if $self->{edit};
    push @a, [table => {border => 1}, \@rows];
    push @a, [input => {type => 'submit', name => 'submit', value => 'Commit'}] if $self->{edit};
    
    my @body = (@error, [ form => {action => $self->{uri}, method => 'POST'}, \@a ]);

    return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
}

1;
