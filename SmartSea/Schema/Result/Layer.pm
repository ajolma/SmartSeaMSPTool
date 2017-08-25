package SmartSea::Schema::Result::Layer;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Storable qw(dclone);
use Scalar::Util 'blessed';
use SmartSea::Schema::Result::RuleClass qw(:all);

my @columns = (
    id          => {},
    use         => { is_foreign_key => 1, source => 'Use', parent => 1, not_null => 1 },
    layer_class => { is_foreign_key => 1, source => 'LayerClass', not_null => 1, no_edit => 1 },
    rule_system => { is_foreign_key => 1, source => 'RuleSystem', is_part => 1, not_null => 1 },
    style       => { is_foreign_key => 1, source => 'Style', is_part => 1, not_null => 1 },
    descr       => { html_input => 'textarea', rows => 10, cols => 20 },
    owner       => {}
    );

__PACKAGE__->table('layers');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(layer_class => 'SmartSea::Schema::Result::LayerClass');
__PACKAGE__->belongs_to(rule_system => 'SmartSea::Schema::Result::RuleSystem');
__PACKAGE__->belongs_to(style => 'SmartSea::Schema::Result::Style');
__PACKAGE__->has_many(rules => 'SmartSea::Schema::Result::Rule', {'foreign.rule_system' => 'self.rule_system'});

# subclassing made with a new table with id pointing to superclass table's pk (super)
# use this method to tell whether an entry is required into this table too
sub subclass {
    my ($self, $columns) = @_;
    if (ref $self) {
        my $class = $self->layer_class->name;
        return 'ImpactLayer' if $class && $class eq 'Impact';
    } elsif ($columns) {
        return 'ImpactLayer' if $columns->{layer_class}->{fixed}->name eq 'Impact';
    }
    return undef;
}

sub relationship_hash {
    return { 
        rules => {
            source => 'Rule',
            ref_to_parent => 'rule_system',
            key => 'rule_system',
            class_widget => sub {
                my ($self, $children) = @_;
                return undef;
            }
        }
    };
}

sub order_by {
    return {-asc => 'id'};
}

sub name {
    my ($self) = @_;
    return $self->use->plan->name.'.'.$self->use->use_class->name.'.'.$self->layer_class->name;
}

sub my_unit {
    return '';
}

sub read {
    my ($self) = @_;
    my @rules;
    for my $rule (sort {$a->criteria->name cmp $b->criteria->name} $self->rules({cookie => ''})) {
        # add only usable rules
        next unless $rule->dataset->usable_in_rule;
        push @rules, $rule->read;
    }
    my $layer = {
        id => $self->id,
        class_id => $self->layer_class->id,
        name => $self->layer_class->name,
        use_id => $self->use->id,
        use_class_id => $self->use->use_class->id,
        owner => $self->owner,
        color_scale => $self->style->color_scale->name,
        rule_class => $self->rule_system->rule_class->name,
        rules => \@rules
    };
    if ($self->rule_system->rule_class->id == BAYESIAN_NETWORK_RULE) {
        for my $key (qw/network output_node output_state/) {
            $layer->{$key} = $self->rule_system->$key;
        }
    }
    return $layer;
}

1;
