package SmartSea::Bayesian_networks;
use parent qw/SmartSea::App/;
use strict;
use warnings;
use 5.010000; # say, //, and //=
use Carp;
use Hugin;

sub smart {
    my ($self, $env, $request, $parameters) = @_;

    my $dir = $self->{data_dir} . 'Bayesian_networks';

    if ($parameters->{name} && $parameters->{accept} eq 'jpeg') {

        my $file = $dir . '/' . $parameters->{name} . '.jpg';
        
        my $content_type = 'image/jpeg';

        open my $fh, "<:raw", $file
            or return $self->http_status(403);

        my @stat = stat $file;

        Plack::Util::set_io_path($fh, Cwd::realpath($file));

        return [
            200,
            [
             'Content-Type'   => $content_type,
             'Content-Length' => $stat[7],
             'Last-Modified'  => HTTP::Date::time2str( $stat[9] )
            ],
            $fh,
            ];
    }
    
    opendir(my $dh, $dir) || croak "Can't opendir $dir: $!";
    my @nets = grep { /\.net$/ && -f "$dir/$_" } readdir($dh);
    closedir $dh;

    my @networks;
    for my $net (@nets) {
        my $name = $net;
        $name =~ s/\.net$//;
        my $network = {name => $name, id => $name};
        my @nodes;
        my $domain = Hugin::Domain::parse_net_file("$dir/$net");
        for my $node ($domain->get_nodes) {
            my $node2 = {id => $node->get_name, name => $node->get_label};
            my @values;
            for my $value ($node->get_state_labels) {
                push @values, $value;
            }
            $node2->{values} = \@values;
            $node2->{attributes} = {$node->get_attributes};
            push @nodes, $node2;
        }
        $network->{nodes} = \@nodes;
        push @networks, $network;
    }   
    
    return $self->json200(\@networks);

}

1;
