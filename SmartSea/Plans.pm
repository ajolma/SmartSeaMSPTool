package SmartSea::Plans;
use parent qw/SmartSea::App/;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Data::GUID;
use SmartSea::Core qw(:all);
use SmartSea::Layer;

sub smart {
    my ($self, $env, $request, $parameters) = @_;
    
    my $plans = $self->{schema}->resultset('Plan')->read;
    
    # two pseudo plans, these will be shown as uses in all real plans
    
    push @$plans, {
        name => 'Data',
        layers => scalar($self->{schema}->resultset('Dataset')->layers)
    };

    push @$plans, {
        name => 'Ecosystem',
        layers => scalar($self->{schema}->resultset('EcosystemComponent')->layers)
    };
        
    # This is the first request made by the App, thus set the cookie
    # if there is not one. The cookie is only for the duration the
    # browser is open.

    unless ($self->{cookie}) {
        my $guid = Data::GUID->new;
        my $cookie = $guid->as_string;
        $self->{header}{'Set-Cookie'} = "SmartSea=$cookie; httponly; Path=/";
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
    return $self->json200($plans);

}

1;
