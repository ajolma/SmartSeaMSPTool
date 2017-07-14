package SmartSea::Schema::Result::RuleSystem;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Schema::Result::RuleClass qw(:all);
use SmartSea::HTML qw(:all);

my @columns = (
    id         => {},
    rule_class => { is_foreign_key => 1, source => 'RuleClass', not_null => 1 }
    );

__PACKAGE__->table('rule_systems');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(rule_class => 'SmartSea::Schema::Result::RuleClass');
__PACKAGE__->has_many(layer => 'SmartSea::Schema::Result::Layer', 'rule_system'); # 0 or 1
__PACKAGE__->has_many(ecosystem_component => 'SmartSea::Schema::Result::EcosystemComponent', 'distribution'); # 0 or 1
__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', 'rule_system');

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
    for my $rule ($self->active_rules($args)) {
        $rule->apply($y, $args);
        if ($args->{debug} && $args->{debug} > 1) {
            my @stats = stats($y); # 3 and 4 are min and max
            my $sum = $y->nelem*$stats[0];
            say STDERR $rule->name,": min=$stats[3], max=$stats[4], sum=$sum";
        }
    }
}

1;
