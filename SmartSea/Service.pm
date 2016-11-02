package SmartSea::Service;
use strict;
use warnings;
use 5.010000; # say // and //=
use Carp;
use Encode qw(decode encode);
use Plack::App::File;
use Geo::GDAL;
use PDL;
use SmartSea::Core;
use SmartSea::HTML;
use SmartSea::Schema;

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
    my $ret = common_responses($env);
    return $ret if $ret;
    my $uri = $env->{REQUEST_URI};
    for ($uri) {
        return $self->uses() if /uses$/;
        return $self->plans() if /plans$/;
        return $self->impact_network() if /impact_network$/;
        return $self->dataset($1) if /datasets([\/\w]*)$/;
        last;
    }
    my @l;
    push @l, [li => a(uses => $uri.'/uses')];
    push @l, [li => a(plans => $uri.'/plans')];
    push @l, [li => a(impact_network => $uri.'/impact_network')];
    push @l, [li => a(datasets => $uri.'/datasets')];
    my $html = SmartSea::HTML->new(html => [body => [ul => \@l]]);
    return html200($html->html);
}

sub dataset {
    my ($self, $set) = @_;
    
    if ($set) {

        $set =~ s/^\///;
        $set = $self->{schema}->resultset('Dataset')->single({ id => $set });
        
        my $body;
        if ($set) {
            my $path = $self->{data_path}.'/'.$set->path;
            my $info = `gdalinfo $path`;
            $body = [[h2 => "GDAL info of ".$set->name.":"], [pre => $info]];
            push @$body, $set->as_HTML_data;
        } else {
            $body = "dataset not found";
        }

        return html200(SmartSea::HTML->new(html => [body => $body])->html);

    } else {

        my @l;
        for $set ($self->{schema}->resultset('Dataset')->search({path => {'!=', undef}})) {
            push @l, [li => a($set->name, 'datasets/'.$set->id)];
        }
        return html200(SmartSea::HTML->new(html => [body => [ul => \@l]])->html);

    }
}

sub uses {
    my $self = shift;
    my @uses;
    for my $use ($self->{schema}->resultset('Use')->search(undef, {order_by => ['me.id']})) {
        my @layers;
        my $rels = $use->use2layer->search(undef, {order_by => { -desc => 'me.layer'}});
        while (my $rel = $rels->next) {
            push @layers, {title => $rel->layer->data, my_id => $rel->layer->id};
        }
        push @uses, {
            title => $use->title,
            my_id => $use->id,
            layers => \@layers
        };
    }
    return json200(\@uses);
}

sub plans {
    my $self = shift;
    my $plans_rs = $self->{schema}->resultset('Plan');
    my $rules_rs = $self->{schema}->resultset('Rule');
    my $uses_rs = $self->{schema}->resultset('Use');
    my @plans;
    for my $plan ($plans_rs->search(undef, {order_by => ['me.title']})) {
        my @rules;
        for my $use ($uses_rs->search(undef, {order_by => ['me.id']})) {
            my @rules_for_use;
            for my $rule ($rules_rs->search({ 'me.plan' => $plan->id,
                                              'me.use' => $use->id },
                                            { order_by => ['me.id'] })) {
                
                push @rules_for_use, {
                    id => $rule->id,
                    text => $rule->as_text($use->title),
                    active => JSON::true
                };
                
            }
            
            push @rules, {
                use => $use->title,
                id => $use->id,
                rules => \@rules_for_use
            }
            
        }
        push @plans, {title => $plan->title, my_id => $plan->id, rules => \@rules};
    }
    return json200(\@plans);
}

sub impact_network {
    my $self = shift;

    my %elements = (nodes => [], edges => []);

    my $uses = $self->{schema}->resultset('Use');
    my $impacts = $self->{schema}->resultset('Impact');
    my $characteristics = $self->{schema}->resultset('Characteristic');

    for my $use ($uses->search(undef, {order_by => ['me.id']})) {
        push @{$elements{nodes}}, { data => { id => 'u'.$use->id, name => $use->title }};
    }
    for my $impact ($impacts->search(undef, {order_by => ['me.id']})) {
        push @{$elements{nodes}}, { data => { id => 'i'.$impact->id, name => $impact->title }};
    }
    for my $characteristic ($characteristics->search(undef, {order_by => ['me.id']})) {
        push @{$elements{nodes}}, { data => { id => 'c'.$characteristic->id, name => $characteristic->title }};
    }

    # uses -> impacts
    for my $use ($uses->search(undef, {order_by => ['me.id']})) {
        my $rels = $use->use2impact;
        while (my $rel = $rels->next) {
            push @{$elements{edges}}, { data => { 
                source => 'u'.$use->id, 
                target => 'i'.$rel->impact->id }};
        }
    }

    # impacts -> characteristics
    for my $impact ($impacts->search(undef, {order_by => ['me.id']})) {
        my $rels = $impact->impact2characteristic;
        while (my $rel = $rels->next) {
            push @{$elements{edges}}, { data => { 
                source => 'i'.$impact->id, 
                target => 'c'.$rel->characteristic->id }};
        }
    }

    return json200(\%elements);
}

1;
