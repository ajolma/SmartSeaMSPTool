package SmartSea::Schema::Result::Impact;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.impacts');
__PACKAGE__->add_columns(qw/ id pressure title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(use2impact => 'SmartSea::Schema::Result::Use2Impact', 'impact');
__PACKAGE__->many_to_many(uses => 'use2impact', 'use');
__PACKAGE__->has_many(impact2characteristic => 'SmartSea::Schema::Result::Impact2Characteristic', 'characteristic');
__PACKAGE__->many_to_many(impacts => 'impact2characteristic', 'impact');

1;
