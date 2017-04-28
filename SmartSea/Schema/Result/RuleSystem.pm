package SmartSea::Schema::Result::RuleSystem;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id         => {},
    rule_class => { is_foreign_key => 1, source => 'RuleClass', required => 1 }
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
    my $name = $self->rule_class->name." $n rules";
    my @layer = $self->layer;
    $name .= " for ".$layer[0]->name if @layer;
    @layer = $self->ecosystem_component;
    $name .= " for ".$layer[0]->name if @layer;
    return $name.'.';
}

1;
