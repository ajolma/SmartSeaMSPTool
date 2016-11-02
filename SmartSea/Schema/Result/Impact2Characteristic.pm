package SmartSea::Schema::Result::Impact2Characteristic;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.impact2characteristic');
__PACKAGE__->add_columns(qw/ impact characteristic /);
__PACKAGE__->set_primary_key(qw/ impact characteristic /);
__PACKAGE__->belongs_to(impact => 'SmartSea::Schema::Result::Impact');
__PACKAGE__->belongs_to(characteristic => 'SmartSea::Schema::Result::Characteristic');

1;
