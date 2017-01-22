package SmartSea::Schema::Result::PUL2Rule;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::Core qw(:all);
use SmartSea::HTML qw(:all);

__PACKAGE__->table('tool.pul2rule');
__PACKAGE__->add_columns(qw/ id pul rule cookie /);
__PACKAGE__->set_primary_key(qw/ id /);
__PACKAGE__->belongs_to(pul => 'SmartSea::Schema::Result::Plan2Use2Layer');
__PACKAGE__->belongs_to(rule => 'SmartSea::Schema::Result::Rule', {'foreign.cookie' => 'self.cookie'});

1;
