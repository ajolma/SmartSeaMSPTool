package SmartSea::Schema::ResultSet::Rule;

use strict; 
use warnings;
use SmartSea::Core qw(:all);

use base 'DBIx::Class::ResultSet';

# PK of rule is (id,cookie), 
# return the one with given id and cookie
# by default return the default rule
sub my_find {
    my ($self, $id, $cookie) = @_;
    $cookie //= DEFAULT;
    my $retval;
    for my $rule ($self->search({ id => $id })) {
        return $rule if $rule->cookie eq $cookie;
        $retval = $rule if $rule->cookie eq DEFAULT;
    }
    return $retval;
}

1;
