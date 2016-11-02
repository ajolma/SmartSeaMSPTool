package SmartSea::Schema::Result::Characteristic;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.characteristics');
__PACKAGE__->add_columns(qw/ id title /);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(impact2characteristic => 'SmartSea::Schema::Result::Impact2Characteristic', 'impact');
__PACKAGE__->many_to_many(characteristics => 'impact2characteristic', 'characteristic');

1;
