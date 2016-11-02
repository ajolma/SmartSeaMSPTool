package SmartSea::Schema::Result::Rule;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.rules');
__PACKAGE__->add_columns(qw/ id plan use reduce r_plan r_use r_layer r_table r_op r_value /);
__PACKAGE__->set_primary_key('id');

# determines whether an area is allocated to a use in a plan
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');

# by default the area is allocated to the use
# if reduce is true, the rule disallocates
# rule consists of an use, layer type, plan (optional, default is this plan)
# operator (optional), value (optional)

__PACKAGE__->belongs_to(r_use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(r_layer => 'SmartSea::Schema::Result::Layer');
__PACKAGE__->belongs_to(r_plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->belongs_to(r_op => 'SmartSea::Schema::Result::Op');

sub as_text {
    my ($self) = @_;
    my $text;
    $text = $self->reduce ? "- If " : "+ If ";
    my $u = '';
    $u = $self->r_use->title if $self->r_use && $self->r_use->title ne $self->use->title;
    if (!$self->r_layer) {
    } elsif ($self->r_layer->data eq 'Value') {
        $u = "for ".$u if $u;
        $text .= $self->r_layer->data.$u;
    } elsif ($self->r_layer->data eq 'Allocation') {
        $u = "of ".$u if $u;
        $text .= $self->r_layer->data.$u;
        $text .= $self->r_plan ? " in plan".$self->r_plan->title : " of this plan";
    } # else?
    if ($self->r_table) {
        $text .= $self->r_table." ";
    }
    return $text."(true)" unless $self->r_op;
    return $text." is ".$self->r_op->op." ".$self->r_value;
}

sub as_HTML_data {
    my ($self) = @_;
    my @l;
    #my %col = $rule->get_columns;
    #sort keys %col
    for my $a (qw/id plan use reduce r_plan r_use r_layer r_table r_op r_value/) {
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

sub HTML_form_data {
    my $values = shift // {};
    my $plan = $values->{plan} // '';
    my $use = $values->{use} // '';
    return [
        [1 => 'plan:'],['br'],[input => {type => 'text', name => 'plan', value => $plan}],['br'],
        [1 => 'use:'],['br'],[input => {type => 'text', name => 'use', value => $use}],['br'],
        [input => {type=>"submit", name=>'input', value=>"Submit"}]
        ];
}

1;
