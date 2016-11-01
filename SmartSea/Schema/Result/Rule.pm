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

1;
