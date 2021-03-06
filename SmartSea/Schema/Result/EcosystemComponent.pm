package SmartSea::Schema::Result::EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);

my @columns = (
    id           => {},
    name         => { data_type => 'text', html_size => 30, not_null => 1},
    distribution => { is_foreign_key => 1, source => 'RuleSystem', is_part => 1, not_null => 1 },
    style        => { is_foreign_key => 1, source => 'Style', is_part => 1, not_null => 1 },
    );

__PACKAGE__->table('ecosystem_components');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(impacts => 'SmartSea::Schema::Result::Impact', 'ecosystem_component');
__PACKAGE__->belongs_to(distribution => 'SmartSea::Schema::Result::RuleSystem');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');
__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', {'foreign.rule_system' => 'self.distribution'});

sub rule_system {
    my $self = shift;
    return $self->distribution;
}

sub relationship_hash {
    return { 
        distribution_rules => {
            source => 'Rule',
            ref_to_parent => 'rule_system',
            key => 'distribution'
        },
        impacts => {
            source => 'Impact',
            ref_to_parent => 'ecosystem_component',
            no_edit => 1
        }
    };
}

sub distribution_rules {
    my $self = shift;
    return $self->rules if $self->distribution;
    return (undef);
}

sub my_unit {
    return '';
}

sub order {
    my $self = shift;
    return $self->id;
}

1;
