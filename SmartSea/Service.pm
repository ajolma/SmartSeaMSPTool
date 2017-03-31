package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Scalar::Util 'blessed';
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);
use SmartSea::Schema;
use SmartSea::Object;
use Data::Dumper;
use Data::GUID;
use GD;

use parent qw/Plack::Component/;

binmode STDERR, ":utf8";

our $debug = 1;

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
    for my $key (sort keys %$env) {
        #say STDERR "$key => $env->{$key}";
    }
    my $ret = common_responses({}, $env);
    return $ret if $ret;
    my $request = Plack::Request->new($env);
    my $cookies = $request->cookies;
    for my $cookie (sort keys %$cookies) {
        #say STDERR "cookie: $cookie => $cookies->{$cookie}";
    }
    my $user = $env->{REMOTE_USER} // 'guest';
    $self->{edit} = 1 if $user eq 'ajolma';
    $self->{cookie} = $cookies->{SmartSea} // DEFAULT;
    $self->{parameters} = $request->parameters;
    $self->{uri} = $env->{REQUEST_URI};
    $self->{origin} = $env->{HTTP_ORIGIN};
    $self->{uri} =~ s/\/$//;
    my @path = split /\//, $self->{uri};
    say STDERR "remote user is $user" if $debug;
    say STDERR "cookie: $self->{cookie}" if $debug;
    say STDERR "uri: $self->{uri}" if $debug;
    say STDERR "path: @path ",scalar(@path) if $debug;
    my @base;
    while (@path) {
        my $step = shift @path;
        push @base, $step;
        return $self->plans(\@path) if $step eq 'plans' || $step eq 'layers';
        return $self->impact_network(\@path) if $step eq 'impact_network';
        return $self->pressure_table(\@path) if $step eq 'pressure_table';
        return $self->legend() if $step =~ /^legend/;
        if ($step eq 'browser') {
            $self->{base_uri} = join('/', @base);
            say STDERR "base_uri: $self->{base_uri}" if $debug;
            return $self->object_editor(\@path);
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
        [li => a(link => 'browser', url  => $uri.'browser')],
        [li => a(link => 'impact_network', url  => $uri.'impact_network')],
        [li => a(link => 'pressure table', url  => $uri.'pressure_table')]
    );
    return html200({}, SmartSea::HTML->new(html => [body => [ul => \@l]])->html);
}

sub legend {
    my ($self, $oids) = @_;

    my $layer = SmartSea::Layer->new({
        schema => $self->{schema},
        trail => $self->{parameters}{layer}});

    my $image = $layer->{duck} ?
        $layer->{style}->legend({
            unit => $layer->unit,
            font => '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            font_size => 10,
            width => 200, # layout.css.right.width
            height => 140,
            symbology_width => 50}) 
        :
        GD::Image->new('/usr/share/icons/cab_view.png');
    
    return [ 200, 
             ['Content-Type' => 'image/png', 'Access-Control-Allow-Origin' => '*'], 
             [$image->png] ];
}

sub plans {
    my ($self, $oids) = @_;
    say STDERR "@$oids" if $debug;
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
        for my $use_class ($plan->use_classes($search, {order_by => 'id'})) {
            my $use = $self->{schema}->
                resultset('Use')->
                single({plan => $plan->id, use_class => $use_class->id});
            my @layers;
            $search = defined $layer_id ? {layer => $layer_id}: undef;
            for my $layer_class ($use->layer_classes($search, {order_by => {-desc => 'id'}})) {
                my $layer = $self->{schema}->
                    resultset('Layer')->
                    single({use => $use->id, layer_class => $layer_class->id});
                my @rules;
                for my $rule ($layer->rules({cookie => DEFAULT})) {
                    push @rules, $rule->as_hashref_for_json
                }
                push @layers, {
                    name => $layer->layer_class->name,
                    style => $layer->style->color_scale->name,
                    id => $layer->layer_class->id, 
                    use => $use->use_class->id, 
                    rules => \@rules};
            }
            push @uses, {name => $use_class->name, id => $use_class->id, plan => $plan->id, layers => \@layers};
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
            next unless $dataset->style;
            next if defined $layer_id && $dataset->id != $layer_id;
            my $range = '';
            if (defined $dataset->style->min) {
                my $u = '';
                $u = ' '.$dataset->my_unit->name if $dataset->my_unit;
                $range = ' ('.$dataset->style->min."$u..".$dataset->style->max."$u)";
            }
            push @datasets, {
                name => $dataset->name, 
                descr => $dataset->lineage,
                style => $dataset->style->color_scale->name.$range,
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
        for my $pressure_class ($activity->pressure_classes) {
            push @{$elements{edges}}, { data => { 
                source => 'a'.$activity->id, 
                target => 'p'.$pressure_class->id }};
            my $ap = $self->{schema}->resultset('Pressure')->
                single({activity => $activity->id, pressure_class => $pressure_class->id});
            for my $impacts ($ap->impacts) {
            }
        }
    }
    for my $pressure_class ($self->{schema}->resultset('PressureClass')->all) {
        push @{$elements{nodes}}, { data => { id => 'p'.$pressure_class->id, name => $pressure_class->name }};
    }

    return json200({}, \%elements);
}

sub object_editor {
    my ($self, $oids) = @_;

    # oids is what's after the base in URI, 
    # a list of object ids separated by / and possibly /new or ?edit in the end
    # DBIx Class understands undef as NULL
    # config: delete => value-in-the-delete-button (default is Delete)
    #         store => value-in-the-store-button (default is Store)
    #         empty_is_null => parameters will be converted to undef if empty strings
    #         defaults => parameters will be set to the value unless in self->parameters
    # 'NULL' parameters will be converted to undef, 

    my $config = {};
    # known requests
    $config->{create} //= 'Create';
    $config->{add} //= 'Add';
    $config->{delete} //= 'Delete';
    $config->{remove} //= 'Remove';
    $config->{store} //= 'Store';
    $config->{save} //= 'Save';
    $config->{modify} //= 'Modify';
    $config->{update} //= 'Update';
    $config->{compute} //= 'Compute';

    my %parameters; # {request}{$request} = 1, key => value

    my %sources = map {$_ => 1} $self->{schema}->sources;

    my $url = $self->{base_uri}.'/';
    unless (@$oids) {
        my @path = split /\//, $self->{base_uri};
        pop @path;
        my @body = a(link => 'Up', url => join('/', @path));
        my @li;
        for my $source (sort keys %sources) {
            next if $source =~ /2/;
            my $lc = $source;
            $lc =~ s/([a-z])([A-Z])/$1_$2/;
            push @li, [li => a(link => SmartSea::Object::plural($source), url => $url.lc($lc))]
        }
        push @body, [ul=>\@li];
        return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
    }

    my ($oid, $request) = split /\?/, $oids->[$#$oids];
    $oids->[$#$oids] = $oid;
    $parameters{request}{$request} = 1 if $request;
    
    # $self->{parameters} is a multivalue hash
    # we may have both object => command and object => id
    for my $key (sort keys %{$self->{parameters}}) {
        for my $value ($self->{parameters}->get_all($key)) {
            if ($key eq 'submit' && $value =~ /^Compute/) {
                $parameters{request}{edit} = 1;
                $parameters{compute} = $value;
                last;
            }
            $value = decode utf8 => $value;
            my $done = 0;
            for my $request (keys %$config) {
                if ($value eq $config->{$request}) {
                    $parameters{request}{$request} = 1;
                    if ($request eq 'delete' or $request eq 'remove') {
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

    for my $p (sort keys %parameters) {
        if ($p eq 'request') {
            for my $r (sort keys %{$parameters{$p}}) {
                say STDERR "request => $r" if $debug;
            }
        } else {
            say STDERR "$p => ".(defined($parameters{$p})?$parameters{$p}:'undef') if $debug;
        }
    }

    my %args = (parameters => \%parameters);
    for my $key (qw/uri base_uri schema edit dbname user pass data_dir/) {
        $args{$key} = $self->{$key};
    }
    $args{cookie} = DEFAULT;

    my $class = '';
    my $rs = ''; #$self->{schema}->resultset($class =~ /(\w+)$/);
    
    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };

    if (!$parameters{request}) {
        my @body = a(link => 'All classes', url => $self->{base_uri});
        my $obj = SmartSea::Object->new({oid => $oids->[0], url => $self->{base_uri}}, $self);
        if ($obj) {
            push @body, [ul => [li => $obj->li($oids, 0)]];
            return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
        }
        
    } elsif ($parameters{request}{modify}) {
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

    }

    return html200({}, SmartSea::HTML->new(html => [body => 'not allowed or error'])->html)
        unless $self->{edit};
    
    if ($parameters{request}{new} or $parameters{request}{add}) {
        my $obj = SmartSea::Object->new({oid => $oids->[$#$oids], url => $self->{base_uri}}, $self);
        if ($obj) {
            my @form = $obj->form($oids, $#$oids, \%parameters);
            if (@form) {
                my $url = $self->{uri};
                $url =~ s/\?.*$//;
                my $form = [form => {action => $url, method => 'POST'}, @form];
                return html200({}, SmartSea::HTML->new(html => [body => $form])->html);
            } else {
                my @body;
                my $error = $obj->create($oids, \%parameters);
                push @body, [p => {style => 'color:red'}, $error] if $@;
                push @body, a(link => 'All classes', url => $self->{base_uri});
                $obj = SmartSea::Object->new({oid => $oids->[0], url => $self->{base_uri}}, $self);
                push @body, [ul => [li => $obj->li($oids, 0)]];
                return html200({}, SmartSea::HTML->new(html => [body => \@body])->html);
            }
        }
        
    } elsif ($parameters{request}{delete} or $parameters{request}{remove}) {
        my %args = (oid => $oids->[$#$oids], url => $self->{base_uri}, id => $parameters{id});
        my $obj = SmartSea::Object->new(\%args, $self);
        if ($obj) {
            my $error = $obj->delete();
            my @body;
            push @body, [p => {style => 'color:red'}, $error] if $error;
            $obj = SmartSea::Object->new({oid => $oids->[0], url => $self->{base_uri}}, $self);
            if ($obj) {
                push @body, a(link => 'All classes', url => $self->{base_uri});
                push @body, [ul => [li => $obj->li($oids, 0)]];
            }
            return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
        }
        
    } elsif ($parameters{request}{store} or $parameters{request}{save}) {
        my %args = (oid => $oids->[$#$oids], url => $self->{base_uri}, id => $parameters{id});
        my $obj = SmartSea::Object->new(\%args, $self);
        if ($obj) {
            my $error = $obj->save($oids, $#$oids, \%parameters);
            if ($error) {
                my $url = $self->{uri};
                $url =~ s/\?.*$//;
                my $form = [form => {action => $url, method => 'POST'}, $obj->form($oids, $#$oids, \%parameters)];
                my @body = ([p => {style => 'color:red'}, $error], $form);
                return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
            } else {
                $obj = SmartSea::Object->new({oid => $oids->[0], url => $self->{base_uri}}, $self);
                if ($obj) {
                    my @body = a(link => 'All classes', url => $self->{base_uri});
                    push @body, [ul => [li => $obj->li($oids, 0)]];
                    return html200({}, SmartSea::HTML->new(html => [body => @body])->html);
                }
            }
        }
        
    } elsif ($parameters{request}{edit}) {
        my %args = (oid => $oids->[$#$oids], url => $self->{base_uri}, id => $parameters{id});
        my $obj = SmartSea::Object->new(\%args, $self);
        if ($obj) {
            my $url = $self->{uri};
            $url =~ s/\?.*$//;
            my $form = [form => {action => $url, method => 'POST'}, $obj->form($oids, $#$oids, \%parameters)];
            return html200({}, SmartSea::HTML->new(html => [body => $form])->html);
        }
        
    }

    return html200({}, SmartSea::HTML->new(html => [body => 'error'])->html);
    
}

sub pressure_table {
    my ($self, $x) = @_;
    my %edits;
    $edits{aps} = $self->{schema}->resultset('Pressure');
    $edits{impacts} = $self->{schema}->resultset('Impact');
    my $pressure_classes = $self->{schema}->resultset('PressureClass');
    my %id;
    my %pressure_classes;
    my %cats;
    for my $pressure_class ($pressure_classes->all) {
        $pressure_classes{$pressure_class->name} = $pressure_class->ordr;
        $id{pressure_classes}{$pressure_class->name} = $pressure_class->id;
        $cats{$pressure_class->name} = $pressure_class->category->name;
    }
    my $activities = $self->{schema}->resultset('Activity');
    my %activities;
    my %name;
    for my $activity ($activities->all) {
        $activities{$activity->name} = $activity->ordr;
        $id{activities}{$activity->name} = $activity->id;
        $name{$activity->name} = $activity->name.'('.$activity->ordr.')';
    }
    my $components = $self->{schema}->resultset('EcosystemComponent');
    my %components;
    for my $component ($components->all) {
        $components{$component->name} = $component->id;
        $id{components}{$component->name} = $component->id;
    }

    for my $pressure_class ($pressure_classes->all) {
        for my $activity ($activities->all) {
            my $key = 'range_'.$pressure_class->id.'_'.$activity->id;
            $name{$key} = $pressure_class->name.' '.$activity->name;

            my $ap = $edits{aps}->single({pressure_class => $pressure_class->id, activity => $activity->id});
            $name{$pressure_class->name}{$activity->name} = $activity->name; #.' '.$ap->id if $ap;
        }
    }

    my %attrs;
    my %ranges;
    for my $ap ($edits{aps}->all) {
        $ranges{$ap->pressure_class->name}{$ap->activity->name} = $ap->range;
        my $key = 'range_'.$ap->pressure_class->id.'_'.$ap->activity->id;
        $attrs{$key} = $ap->range;
        $id{pressure}{$ap->pressure_class->name}{$ap->activity->name} = $ap->id;
    }
    my %impacts;
    for my $impact ($edits{impacts}->all) {
        my $ap = $impact->pressure;
        my $p = $ap->pressure_class;
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
                %single = (pressure_class => $one, activity => $two);
                %params = (pressure_class => $one, activity => $two, $attr => $value);
                $edits = $edits{aps};
            } else {
                next if $value eq '-1';
                %single = (pressure => $one, ecosystem_component => $two);
                %params = (pressure => $one, ecosystem_component => $two, $attr => $value);
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
                    say STDERR "change $key from $attrs{$key} to $value" if $debug;
                    my $obj = $edits->single(\%single);
                    eval {
                        $obj->update(\%params);
                    };
                }
            } else {
                say STDERR "insert $key as $value" if $debug;
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
            $ranges{$ap->pressure_class->name}{$ap->activity->name} = $ap->range;
        }
        for my $impact ($edits{impacts}->all) {
            my $ap = $impact->pressure;
            my $p = $ap->pressure_class;
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
    for my $pressure_class (sort {$pressure_classes{$a} <=> $pressure_classes{$b}} keys %pressure_classes) {
        next unless $pressure_classes{$pressure_class};
        my @activities;
        for my $activity (sort {$activities{$a} <=> $activities{$b}} keys %activities) {
            next unless exists $ranges{$pressure_class}{$activity};
            my $range = $ranges{$pressure_class}{$activity} // 0;
            next if $range < 0;
            push @activities, $activity;
        }
        my @td = ([td => {rowspan => $#activities+1}, $pressure_class]);
        for my $activity (@activities) {
            my $color = $c ? '#cccccc' : '#ffffff';
            push @td, [td => {bgcolor=>$color}, $name{$pressure_class}{$activity}];

            my $idp = $id{pressure_classes}{$pressure_class};
            my $ida = $id{activities}{$activity};
            my $idap = $id{pressure}{$pressure_class}{$activity};

            my $range = $ranges{$pressure_class}{$activity} // 0;
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
                my $impact = $impacts{$pressure_class}{$activity}{$component} // [-1,-1];
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

            if ($cat ne $cats{$pressure_class}) {
                $cat = $cats{$pressure_class};
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
