package SmartSea::Schema::Result::RuleSystem;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Schema::Result::RuleClass qw(:all);
use SmartSea::HTML qw(:all);

our $have_hugin;
BEGIN {
    eval {
        require 'Geo/GDAL/Bayes/Hugin.pm';
    };
    $have_hugin = !$@;
}

my @columns = (
    id         => {},
    rule_class => { is_foreign_key => 1, source => 'RuleClass', not_null => 1 },
    network_file => {data_type => 'text', html_size => 30},
    output_node => {data_type => 'text', html_size => 30},
    output_state => {data_type => 'integer', html_size => 30},
    );

__PACKAGE__->table('rule_systems');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(rule_class => 'SmartSea::Schema::Result::RuleClass');
__PACKAGE__->has_many(layer => 'SmartSea::Schema::Result::Layer', 'rule_system'); # 0 or 1
__PACKAGE__->has_many(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent', 'distribution'); # 0 or 1
__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', 'rule_system');

sub columns_info {
    my ($self, $colnames, $parent) = @_;
    my $info = $self->SUPER::columns_info($colnames);
    for my $col ($self->columns) {
        delete $info->{$col}{not_used};
    }
    my $class;
    if (ref $self) {
        $class = $self->rule_class->id;
    }
    return $info unless $class;
    if ($class != BAYESIAN_NETWORK_RULE) {
        $info->{network_file}{not_used} = 1;
        $info->{output_node}{not_used} = 1;
        $info->{output_state}{not_used} = 1;
    }
    return $info;
}

sub name {
    my $self = shift;
    my @rules = $self->rules;
    my $n = @rules;
    my $name = $self->rule_class->name // '';
    $name .= " $n rules";
    my @layer = $self->layer;
    $name .= " in ".$layer[0]->name if @layer;
    @layer = $self->ecosystem_component;
    $name .= " in ".$layer[0]->name if @layer;
    return $name.'.';
}

sub relationship_hash {
    return {
        rules => {
            name => 'Rule',
            source => 'Rule',
            ref_to_parent => 'rule_system',
        }
    };
}

# return rules where 
# cookie is $args->{cookie} if there is one with that id
# rule->id is in hash $args->{rules} or $args->{rules}{all} is true
sub active_rules {
    my ($self, $args) = @_;
    # no rules is no rules
    my $cookie = $args->{cookie} // '';
    my %rules;
    for my $rule ($self->rules) {
        next unless $args->{rules}{all} || $args->{rules}{$rule->id};
        if ($rule->cookie eq $cookie) {
            $rules{$rule->id} = $rule; # the preferred rule
            next;
        }
        next if $rules{$rule->id};
        $rules{$rule->id} = $rule;
    }
    return values %rules;
}

sub compute {
    my ($self, $y, $args) = @_;
    my $class = $self->rule_class->id;
    if ($class != BAYESIAN_NETWORK_RULE) {
        for my $rule ($self->active_rules($args)) {
            $rule->apply($y, $args);
            if ($args->{debug} && $args->{debug} > 1) {
                my @stats = stats($y); # 3 and 4 are min and max
                my $sum = $y->nelem*$stats[0];
                say STDERR $rule->name,": min=$stats[3], max=$stats[4], sum=$sum";
            }
        }
        
    } else {
        my %evidence;
        my %offsets;
        for my $rule ($self->active_rules($args)) {
            $evidence{$rule->node_id} = $rule->dataset->Band($args);
            $offsets{$rule->node_id} = $rule->state_offset;
        }

        my $output = Geo::GDAL::Driver('MEM')->Create(Type => 'Float64', Width => 256, Height => 256)->Band;
        my $setup = Geo::GDAL::Bayes::Hugin->new({
            domain => $args->{domains}{$self->network_file},
            evidence => \%evidence,
            offsets => \%offsets,
            output => {
                band => $output,
                name => $self->output_node,
                state => $self->output_state,
            }
        });

        $setup->compute();
        $y += $output->Piddle;

    }
}

1;
