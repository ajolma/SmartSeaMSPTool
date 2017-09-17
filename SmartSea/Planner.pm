package SmartSea::Planner;
use parent qw/SmartSea::App/;
use strict;
use warnings;
use 5.010000; # say, //, and //=
use Carp;

sub new {
    my ($class, $self) = @_;
    $self = SmartSea::App->new($self);

    $self->{uses} = {
        1 => 'Tuulivoima',
        2 => 'Kalankasvatus',
        3 => 'Matkailu',
    };
    $self->{colors} = {
        1 => 'rgba(0, 228, 255, 0.6)',
        2 => 'rgba(255, 255, 0, 0.6)',
        3 => 'rgba(0, 255, 0, 0.6)',
    };

    $self->{dbh} = DBI->connect(
        "dbi:Pg:dbname=$self->{db_name}", 
        $self->{db_user}, 
        $self->{db_passwd}, 
        {AutoCommit => 0}) or die $DBI::errstr;

    $self->{user_table} = 'wfs';
    $self->{comparison_table} = 'wfs2';
    
    return bless $self, $class;
}

sub DESTROY {
    my ($self) = @_;
    $self->{dbh}->disconnect;
}

sub smart {
    my ($self, $env, $request, $parameters) = @_;

    my $response = {
        type => 'bar',
        data => {
            labels => [], 
            datasets => [{
                label => 'Alue km2',
                data => [],
                backgroundColor => [],
                borderColor => [],
                borderWidth => 1 }]},
        options => {
            scales => {
                yAxes => [{
                    ticks => {
                        beginAtZero => JSON::true
                    }}]}
        }
    }; # Chart data, one dataset
    my $dataset = $response->{data}{datasets}[0];
    
    my $table = $parameters->{table} // $self->{user_table};
    $table = $self->{comparison_table} unless $table eq $self->{user_table};
    my $sql = 
        "select sum(st_area(geometry)/1000000) as area, use " .
        "from wfs.$table ";
    if ($parameters->{username}) {
        my ($username) = $parameters->{username} =~ /(\w+)/;
        $sql .= "where username = '$username' ";
    }
    $sql .= "group by use order by use";
    #say STDERR $sql;
    my $sth = $self->{dbh}->prepare($sql);
    if ($sth->execute()) {
        while (my $row = $sth->fetchrow_hashref) {
            #say STDERR "$row->{use} $row->{area}";
            $row->{area} = POSIX::round($row->{area});
            push @{$response->{data}{labels}}, $self->{uses}{$row->{use}};
            push @{$dataset->{data}}, $row->{area};
            push @{$dataset->{backgroundColor}}, $self->{colors}{$row->{use}};
            push @{$dataset->{borderColor}}, 'rgba(0,0,0,1)';
        }
    } else {
        say STDERR $sth->errstr;
    }
    
    my $json = JSON->new;
    $json->utf8;
    return [ 200,
             [
              'Content-Type' => 'application/json; charset=utf-8',
              'Access-Control-Allow-Credentials' => 'true',
              'Access-Control-Allow-Origin' => '*'
             ],
             [$json->encode($response)] 
        ];

}

1;
