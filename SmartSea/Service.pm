package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;

use parent qw/Plack::Component/;

#my $data_path = '/home/cloud-user/data';
my $data_path = '/home/ajolma/data/SmartSea';

binmode STDERR, ":utf8"; 

sub new {
    my ($class, $params) = @_;
    my $self = Plack::Component->new($params);
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;
    my $ret = common_responses($env);

    if ($env->{REQUEST_URI} =~ /uses$/) {
        return $self->uses();
    }
    if ($env->{REQUEST_URI} =~ /plans$/) {
        return $self->plans();
    }
    if ($env->{REQUEST_URI} =~ /impact_network$/) {
        return $self->impact_network();
    }
    if ($env->{REQUEST_URI} =~ /datasets([\/\w]*)$/) {
        return $self->dataset($1);
    }

    return $ret if $ret;
    my $request = Plack::Request->new($env);
    my $parameters = $request->parameters;
    for my $key (sort keys %$env) {
        my $val = $env->{$key} // '';
        say STDERR "env: $key => $val";
    }
    for my $key (sort keys %$parameters) {
        my $val = $parameters->{$key} // '';
        say STDERR "params: $key => $val";
    }
    my $report = "foo bar";
    return json200({report => $report});
}

sub a {
    my ($link, $url) = @_;
    return [a => $link, {href=>$url}];
}

sub add_dataset_description {
    my ($this, $sets, $body) = @_;

    my @l;
    push @l, [li => [[b => 'custodian'],[1 => " = $this->{custodian}"]]] if $this->{custodian};
    push @l, [li => [[b => "contact"],[1 => " = $this->{contact}"]]] if $this->{contact};
    push @l, [li => [[b => "description"],[1 => " = $this->{desc}"]]] if $this->{desc};
    push @l, [li => [[b => "disclaimer"],[1 => " = $this->{disclaimer}"]]] if $this->{disclaimer};
    push @l, [li => [[b => "license"],[1 => " = "],a($this->{license}{name}, $this->{license}{url})]] if $this->{license};
    push @l, [li => [[b => "attribution"],[1 => " = $this->{attribution}"]]] if $this->{attribution};
    push @l, [li => [[b => "data model"],[1 => " = $this->{'data model'}"]]] if $this->{'data model'};
    push @l, [li => [[b => "unit"],[1 => " = $this->{unit}"]]] if $this->{unit};
    push @$body, [ul => \@l];

    my $x = $this->{'is a part of'};
    if ($x && $sets->{$x}) {
        my $super = $sets->{$x};
        push @$body, [h2 => "'$this->{name}' is a part of '$super->{name}'"];
        add_dataset_description($super, $sets, $body);
    }
    $x = $this->{'is derived from'};
    if ($x && $sets->{$x}) {
        my $super = $sets->{$x};
        push @$body, [h2 => "'$this->{name}' is derived from '$super->{name}'"];
        add_dataset_description($super, $sets, $body);
    }
}

sub dataset {
    my ($self, $set) = @_;
    $set =~ s/^\///;

    my $dbh = DBI->connect("dbi:Pg:dbname=$self->{dbname}", $self->{user}, $self->{pass}, {AutoCommit => 0});
    
    if ($set) {
        my $sets = $dbh->selectall_hashref("select * from data.datasets", 'id');
        my $custodians = $dbh->selectall_hashref("select * from data.organizations", 'id');
        my $data_models = $dbh->selectall_hashref("select * from data.\"data models\"", 'id');
        my $licenses = $dbh->selectall_hashref("select * from data.licenses", 'id');
        my $units = $dbh->selectall_hashref("select * from data.units", 'id');
        for my $set (keys %$sets) {
            my $s = $sets->{$set};
            $s->{custodian} = $custodians->{$s->{custodian}}{name} if $s->{custodian};
            $s->{'data model'} = $data_models->{$s->{'data model'}}{name} if $s->{'data model'};
            $s->{license} = $licenses->{$s->{license}} if $s->{license};
            $s->{unit} = $units->{$s->{unit}}{title} if $s->{unit};
        }

        my $this = $sets->{$set};
        my $body = "dataset not found";
        
        if ($this) {
            my $info = `gdalinfo $this->{path}`;
            $body = [[h2 => "GDAL info of $this->{name}:"], [pre => $info]];
            add_dataset_description($this, $sets, $body);
        }

        $dbh->disconnect;

        my $html = HTML->new;
        $html->element(html => [body => $body]);
        return html200($html->html);
    }

    my $sets = $dbh->selectall_arrayref("select id,name from data.datasets where not path isnull");
    my @l;
    for my $row (@$sets) {
        push @l, [li => [a => $row->[1], {href=>"datasets/$row->[0]"}]];
    }

    my $html = HTML->new;
    $html->element(html => [body => [ul => \@l]]);
    return html200($html->html);
}

sub uses {
    my $self = shift;
    my $dbh = DBI->connect("dbi:Pg:dbname=$self->{dbname}", $self->{user}, $self->{pass}, {AutoCommit => 0});
    my $uses = $dbh->selectall_arrayref("select use,layer,use_id,layer_id from tool.uses_list");
    my @uses;
    my $title;
    my $id;
    my @layers;
    for my $row (@$uses) {
        my $l = lc($row->[0] .'_'. $row->[1]);
        if ($title and $title ne $row->[0]) {
            push @uses, {
                title => $title,
                my_id => $id,
                layers => [@layers]
            };
            @layers = ();
        }
        $title = $row->[0];
        $id = $row->[2];
        push @layers, {title => $row->[1], my_id => $row->[3]};
    }
    push @uses, {
        title => $title,
        layers => [@layers]
    };
    return json200(\@uses);
}

sub plans {
    my $self = shift;
    my $dbh = DBI->connect("dbi:Pg:dbname=$self->{dbname}", $self->{user}, $self->{pass}, {AutoCommit => 0});
    my $plans = $dbh->selectall_arrayref("select title,id from tool.plans order by title");
    my @plans;
    for my $row (@$plans) {
        push @plans, {title => $row->[0], my_id => $row->[1]};
    }
    return json200(\@plans);
}

sub impact_network {
    my $self = shift;
    my $dbh = DBI->connect("dbi:Pg:dbname=$self->{dbname}", $self->{user}, $self->{pass}, {AutoCommit => 0});

    my $uses = $dbh->selectall_arrayref("select id,title from tool.uses order by id");
    my $impacts = $dbh->selectall_arrayref("select id,title from tool.impacts order by id");
    my $characteristics = $dbh->selectall_arrayref("select id,title from tool.characteristics order by id");
    
    my %elements = (nodes => [], edges => []);
    my @uses;
    for my $row (@$uses) {
        push @{$elements{nodes}}, { data => { id => 'u'.$row->[0], name => $row->[1] }};
        push @uses, $row->[0];
    }
    my @impacts;
    for my $row (@$impacts) {
        push @{$elements{nodes}}, { data => { id => 'i'.$row->[0], name => $row->[1] }};
        push @impacts, $row->[0];
    }
    my @characteristics;
    for my $row (@$characteristics) {
        push @{$elements{nodes}}, { data => { id => 'c'.$row->[0], name => $row->[1] }};
        push @characteristics, $row->[0];
    }
    
    # uses -> impacts
    for my $use (@uses) {
        for my $impact (@impacts) {
            push @{$elements{edges}}, { data => { source => 'u'.$use, target => 'i'.$impact }};
        }
    }

    # impacts -> characteristics
    for my $impact (@impacts) {
        for my $characteristic (@characteristics) {
            push @{$elements{edges}}, { data => { source => 'i'.$impact, target => 'c'.$characteristic }};
        }
    }

    return json200(\%elements);
}

sub json200 {
    my $data = shift;
    my $json = JSON->new;
    $json->utf8;
    return [
        200, 
        [ 'Content-Type' => 'application/json; charset=utf-8',
          'Access-Control-Allow-Origin' => '*' ],
        [$json->encode($data)]];
}

sub return_400 {
    my $self = shift;
    return [400, ['Content-Type' => 'text/plain', 'Content-Length' => 11], ['Bad Request']];
}

sub return_403 {
    my $self = shift;
    return [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']];
}

sub common_responses {
    my $env = shift;
    if (!$env->{'psgi.streaming'}) {
        return [ 500, ["Content-Type" => "text/plain"], ["Internal Server Error (Server Implementation Mismatch)"] ];
    }
    if ($env->{REQUEST_METHOD} eq 'OPTIONS') {
        return [ 200, 
                 [
                  "Access-Control-Allow-Origin" => "*",
                  "Access-Control-Allow-Methods" => "GET,POST",
                  "Access-Control-Allow-Headers" => "origin,x-requested-with,content-type",
                  "Access-Control-Max-Age" => 60*60*24
                 ], 
                 [] ];
    }
    return undef;
}

sub html200 {
    my $html = shift;
    return [ 200, 
             [ 'Content-Type' => 'text/html; charset=utf-8',
               'Access-Control-Allow-Origin' => '*' ], 
             [encode utf8 => $html]
        ];
}

{
    package HTML;
    use strict;
    use warnings;
    our @ISA = qw(Geo::OGC::Service::XMLWriter);
    sub new {
        return bless {}, 'HTML';
    }
    sub write {
        my $self = shift;
        my $line = shift;
        push @{$self->{cache}}, $line;
    }
    sub html {
        my $self = shift;
        return join '', @{$self->{cache}};
    }
}

1;
