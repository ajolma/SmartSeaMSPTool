package SmartSea::Feedback;
use parent qw/SmartSea::App/;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use SmartSea::Core qw(:all);
use SmartSea::Layer;

sub smart {
    my ($self, $env, $request, $parameters) = @_;

    my $encoding = $request->content_encoding // 'utf8';

    my $aihe = decode $encoding => $parameters->{aihe} // 'ei aihetta';
    my $palaute = decode $encoding => $parameters->{palaute} // 'ei palautetta';

    my $dbh = DBI->connect("dbi:Pg:dbname=$self->{db_name}", $self->{db_user}, $self->{db_passwd}) or croak('no db');
    my $a = encode utf8 => $aihe;
    $a =~ s/'//g;
    my $p = encode utf8 => $palaute;
    $p =~ s/'//g;
    unless ($dbh->do("insert into palaute (aika,aihe,palaute) values (current_timestamp,'$a','$p')")) {
        say STDERR $dbh->errstr;
        return $self->http_status(500);
    }

    $aihe = "Palaute SmartSea-sovelluksesta: ".$aihe;
    $palaute = "Palaute: ".$palaute."\n";

    my $message = Email::MIME->create(
	header_str => [
            From    => 'Ari Jolma <ari.jolma@gmail.com>',
            To      => 'Ari Jolma <ari.jolma@gmail.com>',
            Subject => $aihe,
	],
        attributes => {
            encoding => 'quoted-printable',
            charset  => 'UTF-8',
	},
        body_str => $palaute,
	);
    sendmail($message);

    return $self->json200({result => 'ok'});

}

1;
