package SmartSea::Schema::Result::Rule;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.rules');
__PACKAGE__->add_columns(qw/ id plan use reduce r_use r_layer r_plan r_op r_value /);
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
    my ($self, $use_title) = @_;
    my $text;
    $text = $self->reduce ? "- " : "+ ";
    my $u = '';
    $u = $self->r_use->title if $self->r_use->title ne $use_title;
    if ($self->r_layer->data eq 'Value') {
        $u = " for ".$u if $u;
        $text .= $self->r_layer->data.$u;
    } elsif ($self->r_layer->data eq 'Allocation') {
        $u = " of ".$u if $u;
        $text .= $self->r_layer->data.$u;
        $text .= $self->r_plan ? " in plan".$self->r_plan->title : " of this plan";
    } # else?
    $text .= " is ".$self->r_op->op." ".$self->r_value;
}

1;
