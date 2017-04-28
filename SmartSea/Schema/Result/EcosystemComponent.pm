package SmartSea::Schema::Result::EcosystemComponent;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML qw(:all);
use SmartSea::Impact qw(:all);

my @columns = (
    id           => {},
    name         => { data_type => 'text', html_size => 30},
    distribution => { is_foreign_key => 1, source => 'RuleSystem', is_composition => 1 },
    style        => { is_foreign_key => 1, source => 'Style', is_composition => 1 },
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

sub children_listers {
    return { 
        _rules => {
            source => 'Rule',
            class_name => 'Rules',
            child_is_mine => 1,
            for_child_form => sub {
                my ($self, $children) = @_;
                return undef;
            }
        }
    };
}

sub _rules {
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
