use v5.10;
use strict;
use warnings;
use Encode qw(decode encode);
use JSON;
use Crypt::PasswdMD5;
use Plack::Builder;
use Geo::OGC::Service;
use Geo::OGC::Service::WFS;
use Geo::OGC::Service::WMTS;
use Plack::App::File;

use SmartSea::HTML qw(:all);
use SmartSea::WMTS;
use SmartSea::Legend;
use SmartSea::Plans;
use SmartSea::Bayesian_networks;
use SmartSea::Explain;
use SmartSea::Browser;
use SmartSea::Planner;

my $N = 0;
my @services;
my $confdir = '/var/www/etc/';
my $conf = 'smartsea-service.conf';
my %conf;
open(my $fh, "<", $confdir.$conf) or die "Can't open < $confdir.$conf: $!";
while (<$fh>) {
    chomp;
    my ($key, $value) = /^(\w+) = (.*)$/;
    $conf{$key} = $value;
}
for my $key (qw/https server root src_dir db_name db_user db_passwd data_dir image_dir OGC_Service_conf/) {
    die "Missing configuration variable '$key'." unless defined $conf{$key};
}
if ($conf{Hugin} eq 'yes') {
} elsif ($conf{Hugin} eq 'auth') {
    $ENV{HUGINAUTH} = 1;
    #say STDERR "Hugin requires authentication.";
} else {
    undef $SmartSea::Schema::Result::RuleSystem::have_hugin;
    #say STDERR "Hugin support off.";
}


sub authen_cb {
    my ($username, $password, $env) = @_;
    #say STDERR "auth attempt: $username, $password";
    return 0 unless $username && $password;
    if ($conf{https}) {
        return 0 unless $env->{HTTP_X_REAL_PROTOCOL} && $env->{HTTP_X_REAL_PROTOCOL} eq 'https';
    }
    my $passwd_file = $confdir.'smartsea.passwd';
    return 0 unless -r $passwd_file;
    my $l = `grep $username $passwd_file`;
    chomp($l);
    my (undef, $pwd) = split /:/, $l;
    my $crypted = apache_md5_crypt($password, $pwd);
    return 0 unless defined $crypted;
    return $crypted eq $pwd;
}

my %services = (
    wxs => 'Layers through the map tile service using distinct protocols.',
    pressure_table => 'HTML table of pressures created by activities and their impacts, '.
                      'including beliefs in them, on ecological components.',
    plans => 'JSON of all plans, including uses, layers, and rules; mapped ecosystem components; and datasets with styles.',
    networks => 'JSON of all Bayesian Networks.',
    browser => 'Object-oriented access to the dataset, plan, and impact database. HTML and JSON.',
    legend => 'Legend API. Expects layer parameter.',
    explain => 'Map query API. Expects WKT (Polygon) or Easting/Northing (Point) and layer parameters.',
    app => 'The mapping app. Authenticated version supports modeling.',
    planner => '',
    WFS => '',
    config => ''
);

for my $set (0..$N) {

    my $postfix = $set == 0 ? '' : '_'.$set;
    my $on_connect = "SET search_path TO tool$postfix,data$postfix,public";
    my $schema = SmartSea::Schema->connect(
        "dbi:Pg:dbname=$conf{db_name}",
        $conf{db_user},
        $conf{db_passwd},
        { on_connect_do => [$on_connect] });

    for my $service (sort keys %services) {
        for my $auth (qw/none auth/) {

            my %config = (
                db_name => $conf{db_name},
                db_user => $conf{db_user},
                db_passwd => $conf{db_passwd},
                table_postfix => $postfix,
                sequences => 1,
                schema => $schema,
                data_dir => $conf{data_dir},
                images => $conf{image_dir},
                home => $conf{root},
                root => $conf{root},
                edit => 0,
                debug => 1
                );

            $config{root} .= '/auth' if $auth eq 'auth';

            my $app;

            if ($service ne 'wxs') {
                $config{root} .= '/'.$service;
            }

            if ($service eq 'wxs') {

                my $plugin = SmartSea::WMTS->new(\%config);

                $app = Geo::OGC::Service->new({
                    config => $confdir.$conf{OGC_Service_conf},
                    plugin => $plugin,
                    services => {
                        WMTS => 'Geo::OGC::Service::WMTS',
                        WMS => 'Geo::OGC::Service::WMTS',
                        TMS => 'Geo::OGC::Service::WMTS',
                    }})->to_app;

            } elsif ($service eq 'WFS') {

                $app = Geo::OGC::Service->new({
                    config => $confdir.$conf{OGC_Service_conf},
                    services => {
                        WFS => 'Geo::OGC::Service::WFS',
                    }})->to_app;

            } elsif ($service eq 'legend') {

                $app = SmartSea::Legend->new(\%config)->to_app;

            } elsif ($service eq 'plans') {

                $app = SmartSea::Plans->new(\%config)->to_app;

            } elsif ($service eq 'networks') {

                $app = SmartSea::Bayesian_networks->new(\%config)->to_app;

            } elsif ($service eq 'explain') {

                $app = SmartSea::Explain->new(\%config)->to_app;

            } elsif ($service eq 'browser') {

                $app = SmartSea::Browser->new(\%config)->to_app;

            } elsif ($service eq 'pressure_table') {

                $app = sub {
                    my $env = shift;
                    my $request = Plack::Request->new($env);
                    my $user = $env->{REMOTE_USER} // 'guest';
                    my $body = $schema->resultset('Pressure')->table(
                        $schema,
                        $request->parameters,
                        $user ne 'guest',
                        $env->{REQUEST_URI}
                        );
                    my $html = SmartSea::HTML->new(html => [body => $body])->html;
                    return [ 200, [], [encode utf8 => '<!DOCTYPE html>'.$html] ];
                };

            } elsif ($service eq 'app') {

                my $index = $conf{src_dir}.'index.html';
                my @file = `cat $index`;
                $app = sub {
                    my $env = shift;
                    return [ 200, ['Content-Type' => 'text/html'], \@file ];
                };

            } elsif ($service eq 'planner') {

                $app = SmartSea::Planner->new(\%config)->to_app;

            } elsif ($service eq 'config') {

                $app = sub {
                    my $env = shift;
                    my $json = JSON->new;
                    $json->utf8;
                    my $user = $env->{REMOTE_USER} // 'guest';
                    my $protocol = $env->{HTTP_X_REAL_PROTOCOL} // 'http';
                    my $auth = $user eq 'guest' ? JSON::false : JSON::true;
                    my $server = $conf{server}.$conf{root};
                    $server .= '/auth' if $auth == JSON::true;
                    my $response = {
                        protocol => $protocol,
                        server => $server,
                        user => $user,
                        auth => $auth,
                    };
                    if ($auth == JSON::true) {
                        for my $key (qw/server username password user_type comparison_type feature_ns/) {
                            $response->{'wfs_' . $key} = $conf{'wfs_' . $key};
                        }
                    }
                    return [ 200,
                             [
                              'Content-Type' => 'application/json; charset=utf-8',
                              'Access-Control-Allow-Credentials' => 'true',
                              'Access-Control-Allow-Origin' => '*'
                             ],
                             [$json->encode($response)] ];                    
                };

            }

            if ($auth eq 'auth') {
                $services[$set]{$service}{$auth}{app} = builder {
                    enable "Auth::Basic", authenticator => \&authen_cb;
                    $app;
                };
            } else {
                $services[$set]{$service}{$auth}{app} = builder { $app; };
            }
            $services[$set]{$service}{$auth}{path} = $config{root};
        }
    }

}

my @body;

for my $set (0..$N) {
    my $path = $set == 0 ? $conf{root} : $conf{root}.'/'.$set;
    my @service_links;
    for my $service (sort keys %services) {
        my $dt;
        if ($service eq 'wxs') {
            $dt = [
                a(url => "$path/WMTS", link => 'WMTS'),
                [0 => ' '],
                a(url => "$path/WMS", link => 'WM(T)S'),
                [0 => ' '],
                a(url => "$path/TMS", link => 'TMS')
                ];
        } else {
            my $name = $service;
            $name =~ s/^(\w)/uc($1)/e;
            $name =~ s/_/ /g;
            $dt = [a(url => "http://$conf{server}$path/$service", link => $name)];
            my $url = "$path/auth/$service";
            if ($conf{https}) {
                $url = 'https://' . $conf{server} . $url;
            } else {
                $url = 'http://' . $conf{server} . $url;
            }
            push @$dt, [0 => ' '], a(url => $url, link => 'Authenticated version');
        }
        push @service_links, [dt => $dt];
        if ($conf{https}) {
            push @service_links, [dd => $services{$service}];
        }
    }
    push @body, [ p => "Set $set" ] if $N > 0;
    push @body, [ dl => \@service_links ];

    my $url = "$path/auth/planner-app/index.html";
    $url = 'https://' . $conf{server} . $url if $conf{https};
    push @body, a(url => $url, link => 'Planner App');
}

my $default = sub {
    my $env = shift;
    my $html = SmartSea::HTML->new(html => [body => \@body])->html;
    return [ 200, 
             ['Content-Type' => 'text/html'], 
             [encode utf8 => '<!DOCTYPE html>'.$html] ];
};

builder {
    for my $set (0..$N) {
        for my $service (keys %{$services[$set]}) {
            for my $auth (keys %{$services[$set]{$service}}) {
                my $system = $services[$set]{$service}{$auth};
                my $path = $system->{path};
                if ($service eq 'wxs') {
                    mount $path."/WMTS" => $system->{app};
                    mount $path."/WMS" => $system->{app};
                    mount $path."/TMS" => $system->{app};
                } else {
                    mount $path => $system->{app};
                }
            }
        }
    }
    for my $auth ('', '/auth') {
        mount $conf{root}.$auth."/planner-app" => Plack::App::File->new(root => $conf{planner_app})->to_app;
        
        mount $conf{root}.$auth."/js" => Plack::App::File->new(root => $conf{src_dir}."js")->to_app;
        mount $conf{root}.$auth."/css" => Plack::App::File->new(root => $conf{src_dir}."css")->to_app;
        mount $conf{root}.$auth."/img" => Plack::App::File->new(root => $conf{src_dir}."img")->to_app;
        mount $auth."/js" => Plack::App::File->new(root => $conf{src_dir}."js")->to_app;
        mount $auth."/css" => Plack::App::File->new(root => $conf{src_dir}."css")->to_app;
        mount $auth."/img" => Plack::App::File->new(root => $conf{src_dir}."img")->to_app;
    }
    mount "/" => $default;
};
