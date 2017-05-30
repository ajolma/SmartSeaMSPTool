package SmartSea::Plans;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Data::GUID;
use SmartSea::Core qw(:all);
use SmartSea::Layer;

use parent qw/Plack::Component/;

sub new {
    my ($class, $self) = @_;
    $self = Plack::Component->new($self);
    return bless $self, $class;
}

sub call {
    my ($self, $env) = @_;

    my $ret = common_responses({}, $env);
    return $ret if $ret;
    my $request = Plack::Request->new($env);
    $self->{cookie} = $request->cookies->{SmartSea} // DEFAULT;
    
    my $plans = $self->{schema}->resultset('Plan')->array_of_trees;
    
    # two pseudo plans, these will be shown as uses in all real plans
    # Data and Ecosystem have reserved ids
    # see Layer.pm, WMTS.pm and msp.js
    
    push @$plans, { 
        name => 'Data', 
        id => 0,
        uses => [{
            name => 'Data',
            id => 0,
            class_id => 0,
            layers => scalar($self->{schema}->resultset('Dataset')->layers) }]
    };

    push @$plans, {
        name => 'Ecosystem',
        id => 1,
        uses => [{
            name => 'Ecosystem',
            id => 1,
            class_id => 1,
            layers => scalar($self->{schema}->resultset('EcosystemComponent')->layers) }]
    };
        
    # This is the first request made by the App, thus set the cookie
    # if there is not one. The cookie is only for the duration the
    # browser is open.

    my $header = {
        'Access-Control-Allow-Origin' => $env->{HTTP_ORIGIN},
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
            for my $rule ($self->{schema}->resultset('Rule')->search({ cookie => $self->{cookie} })) {
                $rule->delete;
            }
        };
        say STDERR 'Error: '.$@ if $@;

    }
    return json200($header, $plans);

}

1;
