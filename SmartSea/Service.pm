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

        return html200(SmartSea::HTML->new(html => [body => $body])->html);
    }

    my $sets = $dbh->selectall_arrayref("select id,name from data.datasets where not path isnull");
    my @l;
    for my $row (@$sets) {
        push @l, [li => [a => $row->[1], {href=>"datasets/$row->[0]"}]];
    }

    return html200(SmartSea::HTML->new(html => [body => [ul => \@l]])->html);
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
                
                my $text;
                $text = $rule->reduce ? "- " : "+ ";
                if ($rule->r_layer->data eq 'Value') {
                    $text .= $rule->r_layer->data." for ".$rule->r_use->title;
                } elsif ($rule->r_layer->data eq 'Allocation') {
                    $text .= $rule->r_layer->data." of ".$rule->r_use->title;
                    $text .= $rule->r_plan ? " in plan".$rule->r_plan->title : " of this plan";
                } # else?
                $text .= " is ".$rule->r_op->op." ".$rule->r_value;

                push @rules_for_use, {
                    id => $rule->id,
                    text => $text
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

1;
