package SmartSea::Schema::Result::Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use Scalar::Util 'blessed';
use SmartSea::HTML;

__PACKAGE__->table('tool.rules');
__PACKAGE__->add_columns(qw/ id plan use reduce r_plan r_use r_layer r_dataset op value /);
__PACKAGE__->set_primary_key('id');

# determines whether an area is allocated to a use in a plan
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');

# by default the area is allocated to the use
# if reduce is true, the rule disallocates
# rule consists of an use, layer type, plan (optional, default is this plan)
# operator (optional), value (optional)

__PACKAGE__->belongs_to(r_plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(r_use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(r_layer => 'SmartSea::Schema::Result::Layer');

__PACKAGE__->belongs_to(r_dataset => 'SmartSea::Schema::Result::Dataset');

__PACKAGE__->belongs_to(op => 'SmartSea::Schema::Result::Op');


sub as_text {
    my ($self) = @_;
    my $text;
    $text = $self->reduce ? "- If " : "+ If ";
    my $u = '';
    $u = $self->r_use->title if $self->r_use && $self->r_use->title ne $self->use->title;
    if (!$self->r_layer) {
    } elsif ($self->r_layer->title eq 'Value') {
        $u = "for ".$u if $u;
        $text .= $self->r_layer->title.$u;
    } elsif ($self->r_layer->title eq 'Allocation') {
        $u = "of ".$u if $u;
        $text .= $self->r_layer->title.$u;
        $text .= $self->r_plan ? " in plan".$self->r_plan->title : " of this plan";
    } # else?
    if ($self->r_dataset) {
        $text .= $self->r_dataset->long_name." ";
    }
    return $text."(true)" unless $self->op;
    return $text." is ".$self->op->op." ".$self->value;
}

sub as_HTML_data {
    my ($self) = @_;
    my @l;
    #my %col = $rule->get_columns;
    #sort keys %col
    for my $a (qw/id plan use reduce r_plan r_use r_layer r_dataset op value/) {
        my $v = $self->$a // '';
        if (ref $v) {
            for my $b (qw/title name data op id/) {
                if ($v->can($b)) {
                    $v = $v->$b;
                    last;
                }
            }
        }
        push @l, [li => "$a: ".$v];
    }
    return [ul => \@l];
}

sub HTML_form {
    my ($self, $schema, $values) = @_;
    if ($self and blessed($self) and $self->isa('SmartSea::Schema::Result::Rule')) {
        for my $key (qw/plan use reduce r_plan r_use r_layer r_dataset op value/) {
            next unless $self->$key;
            next if defined $values->{$key};
            $values->{$key} = ref($self->$key) ? $self->$key->id : $self->$key;
        }
    }

    my %plans;
    for my $plan ($schema->resultset('Plan')->all) {
        $plans{$plan->id} = $plan->title;
    }
    my $plan = SmartSea::HTML->select(
        name => 'plan',
        values => [sort {$plans{$a} cmp $plans{$b}} keys %plans], 
        visuals => \%plans,
        selected => $values->{plan} // ''
    );

    my %uses;
    for my $use ($schema->resultset('Use')->all) {
        $uses{$use->id} = $use->title;
    }
    my $use = SmartSea::HTML->select(
        name => 'use',
        values => [sort {$a <=> $b} keys %uses], 
        visuals => \%uses, 
        selected => $values->{use} // ''
    );

    my $reduce = SmartSea::HTML->checkbox(
        name => 'reduce',
        visual => 'Rule removes allocation',
        checked => $values->{reduce}
    );

    my %r_plans;
    my %visuals = ('NULL' => '');
    for my $r_plan ($schema->resultset('Plan')->all) {
        $r_plans{$r_plan->id} = $r_plan->title;
        $visuals{$r_plan->id} = $r_plan->title;
    }
    my $r_plan = SmartSea::HTML->select(
        name => 'r_plan',
        values => ['NULL', sort {$r_plans{$a} cmp $r_plans{$b}} keys %r_plans], 
        visuals => \%visuals,
        selected => $values->{r_plan} // 'NULL'
    );

    my %r_uses;
    %visuals = ('NULL' => '');
    for my $r_use ($schema->resultset('Use')->all) {
        $r_uses{$r_use->id} = $r_use->title;
        $visuals{$r_use->id} = $r_use->title;
    }
    my $r_use = SmartSea::HTML->select(
        name => 'r_use',
        values => ['NULL', sort {$r_uses{$a} cmp $r_uses{$b}} keys %r_uses], 
        visuals => \%visuals,
        selected => $values->{r_use} // 'NULL'
    );

    my %r_layers;
    %visuals = ('NULL' => '');
    for my $r_layer ($schema->resultset('Layer')->all) {
        $r_layers{$r_layer->id} = $r_layer->title;
        $visuals{$r_layer->id} = $r_layer->title;
    }
    my $r_layer = SmartSea::HTML->select(
        name => 'r_layer',
        values => ['NULL', sort {$r_layers{$a} cmp $r_layers{$b}} keys %r_layers], 
        visuals => \%visuals,
        selected => $values->{r_layer} // 'NULL'
    );

    my %r_datasets;
    %visuals = ('NULL' => '');
    for my $r_dataset ($schema->resultset('Dataset')->all) {
        next unless $r_dataset->path;
        $r_datasets{$r_dataset->id} = $r_dataset->long_name;
        $visuals{$r_dataset->id} = $r_dataset->long_name;
    }
    my $r_dataset = SmartSea::HTML->select(
        name => 'r_dataset',
        values => ['NULL', sort {$r_datasets{$a} cmp $r_datasets{$b}} keys %r_datasets], 
        visuals => \%visuals,
        selected => $values->{r_dataset} // 'NULL'
    );

    my %ops;
    %visuals = ('NULL' => '');
    for my $op ($schema->resultset('Op')->all) {
        $ops{$op->id} = $op->op;
        $visuals{$op->id} = $op->op;
    }
    my $op = SmartSea::HTML->select(
        name => 'op',
        values => ['NULL', sort {$a <=> $b} keys %ops], 
        visuals => \%visuals,
        selected => $values->{op} // 'NULL'
    );

    my $value = SmartSea::HTML->text(
        name => 'value',
        visual => $values->{value} // ''
    );

    return [
        [ p => [[1 => 'plan: '],$plan] ],
        [ p => [[1 => 'use: '],$use] ],
        [ p => $reduce ],
        [ p => 'Layer in the rule:' ],
        [ p => [[1 => 'plan: '],$r_plan] ],
        [ p => [[1 => 'use: '],$r_use] ],
        [ p => [[1 => 'layer: '],$r_layer] ],
        [ p => 'or' ],
        [ p => [[1 => 'dataset: '],$r_dataset] ],
        [ p => [[1 => 'Operator and value: '],$op,$value] ],
        [input => {type=>"submit", name=>'input', value=>"Store"}]
        ];
}

1;
