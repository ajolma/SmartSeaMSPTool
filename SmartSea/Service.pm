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

use parent qw/Plack::Component/;

binmode STDERR, ":utf8";

sub new {
    my ($class, $self) = @_;
    $self = Plack::Component->new($self);
    my $dsn = "dbi:Pg:dbname=$self->{dbname}";
    $self->{schema} = SmartSea::Schema->connect($dsn, $self->{user}, $self->{pass}, {});
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    my $ret = common_responses({}, $env);
    return $ret if $ret;
    $self->{edit} = 1 if $env->{REMOTE_USER} && $env->{REMOTE_USER} eq 'ajolma';
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
    say STDERR "@path";
    my @base;
    while (@path) {
        my $step =shift @path;
        say STDERR $step;
        push @base, $step;
        return $self->plans(\@path) if $step eq 'plans';
        return $self->impact_network(\@path) if $step eq 'impact_network';
        return $self->pressure_table(\@path) if $step eq 'pressure_table';
        if ($step eq 'browser') {
            $step = shift(@path) // '';
            push @base, $step;
            $self->{base_uri} = join('/', @base);
            my $class = 'SmartSea::Schema::Result::';
            return $self->object_editor($class.'Plan', \@path) if $step eq 'plans';
            return $self->object_editor($class.'Use', \@path) if $step eq 'uses';
            return $self->object_editor($class.'Activity', \@path) if $step eq 'activities';
            return $self->object_editor($class.'Layer', \@path) if $step eq 'layers';
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

sub plans {
    my ($self, $oids) = @_;
    say STDERR "@$oids";
    my $plan_id = shift @$oids;
    my $schema = $self->{schema};
    my @plans;
    my $search = defined $plan_id ? {id => $plan_id}: undef;
    for my $plan ($schema->resultset('Plan')->search($search, {order_by => {-desc => 'title'}})) {
        my @uses;
        for my $use ($plan->uses(undef, {order_by => 'id'})) {
            my $plan2use = $self->{schema}->
                resultset('Plan2Use')->
                single({plan => $plan->id, use => $use->id});
            my @layers;
            for my $layer ($plan2use->layers(undef, {order_by => {-desc => 'id'}})) {
                my $pul = $self->{schema}->
                    resultset('Plan2Use2Layer')->
                    single({plan2use => $plan2use->id, layer => $layer->id});
                my @rules;
                for my $rule ($pul->rules(
                                  {
                                      cookie => DEFAULT
                                  },
                                  {
                                      order_by => { -asc => 'my_index' }
                                  })) {
                    push @rules, $rule->as_hashref_for_json
                }
                push @layers, {title => $layer->title, id => $layer->id, use => $use->id, rules => \@rules};
            }
            push @uses, {title => $use->title, id => $use->id, plan => $plan->id, layers => \@layers};
        }
        push @plans, {title => $plan->title, id => $plan->id, uses => \@uses};
    }

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
        push @{$elements{nodes}}, { data => { id => 'a'.$activity->id, name => $activity->title }};
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
        push @{$elements{nodes}}, { data => { id => 'p'.$pressure->id, name => $pressure->title }};
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
    for my $key (qw/uri base_uri schema edit dbname user pass data_path/) {
        $args{$key} = $self->{$key};
    }

    my $rs = $self->{schema}->resultset($class =~ /(\w+)$/);
    my @body;
    # to make jQuery happy:
    my $header = { 'Access-Control-Allow-Origin' => $self->{origin},
                   'Access-Control-Allow-Credentials' => 'true' };
    if ($parameters{request} eq 'create' and $self->{edit}) {
        eval {
            $rs->create($class->create_col_data(\%parameters));
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
        $args{oids} = [@$oids];
        my $obj = $class->get_object(%args);
        # only modify if $self->{cookie} ne default
        return http_status($header, 403) if $self->{cookie} eq DEFAULT; # forbidden 
        my $cols = $obj->values;
        $cols->{value} = $parameters{value};
        $cols->{id} = $obj->id;
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
            $obj->update($obj->update_col_data(\%parameters));
        };
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
        $pressures{$pressure->title} = $pressure->order;
        $id{pressures}{$pressure->title} = $pressure->id;
        $cats{$pressure->title} = $pressure->category->title;
    }
    my $activities = $self->{schema}->resultset('Activity');
    my %activities;
    my %title;
    for my $activity ($activities->all) {
        $activities{$activity->title} = $activity->order;
        $id{activities}{$activity->title} = $activity->id;
        $title{$activity->title} = $activity->title.'('.$activity->order.')';
    }
    my $components = $self->{schema}->resultset('EcosystemComponent');
    my %components;
    for my $component ($components->all) {
        $components{$component->title} = $component->order;
        $id{components}{$component->title} = $component->id;
    }

    for my $pressure ($pressures->all) {
        for my $activity ($activities->all) {
            my $key = 'range_'.$pressure->id.'_'.$activity->id;
            $title{$key} = $pressure->title.' '.$activity->title;

            my $ap = $edits{aps}->single({pressure => $pressure->id, activity => $activity->id});
            $title{$pressure->title}{$activity->title} = $activity->title; #.' '.$ap->id if $ap;
        }
    }

    my %attrs;
    my %ranges;
    for my $ap ($edits{aps}->all) {
        $ranges{$ap->pressure->title}{$ap->activity->title} = $ap->range;
        my $key = 'range_'.$ap->pressure->id.'_'.$ap->activity->id;
        $attrs{$key} = $ap->range;
        $id{activity2pressure}{$ap->pressure->title}{$ap->activity->title} = $ap->id;
    }
    my %impacts;
    for my $impact ($edits{impacts}->all) {
        my $ap = $impact->activity2pressure;
        my $p = $ap->pressure;
        my $a = $ap->activity;
        my $e = $impact->ecosystem_component;
        my $title = $p->title.'+'.$a->title.' -> '.$e->title;
        $impacts{$p->title}{$a->title}{$e->title} = [$impact->strength,$impact->belief];
        my $key = 'strength_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->strength;
        $title{$key} = $title;
        $key = 'belief_'.$ap->id.'_'.$e->id;
        $attrs{$key} = $impact->belief;
        $title{$key} = $title;
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
            $ranges{$ap->pressure->title}{$ap->activity->title} = $ap->range;
        }
        for my $impact ($edits{impacts}->all) {
            my $ap = $impact->activity2pressure;
            my $p = $ap->pressure;
            my $a = $ap->activity;
            my $e = $impact->ecosystem_component;
            $impacts{$p->title}{$a->title}{$e->title} = [$impact->strength,$impact->belief];
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
            push @td, [td => {bgcolor=>$color}, $title{$pressure}{$activity}];

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
