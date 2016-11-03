package SmartSea::Schema::Result::Use2Impact;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('tool.use2impact');
__PACKAGE__->add_columns(qw/ use impact /);
__PACKAGE__->set_primary_key(qw/ use impact /);
__PACKAGE__->belongs_to(use => 'SmartSea::Schema::Result::Use');
__PACKAGE__->belongs_to(impact => 'SmartSea::Schema::Result::Impact');

1;
