package SmartSea::Schema::Result::Zoning;
use strict;
use warnings;
use 5.010000;
use base qw/DBIx::Class::Core/;
use SmartSea::HTML qw(:all);

my @columns = (
    id   => {},
    name => {data_type => 'text', html_size => 30, not_null => 1},
    plan => {is_foreign_key => 1, source => 'Plan', not_null => 1},
    );

__PACKAGE__->table('zonings');
__PACKAGE__->add_columns(@columns);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(plan => 'SmartSea::Schema::Result::Plan');
__PACKAGE__->has_many(bridges => 'SmartSea::Schema::Result::Use2Zoning', 'zoning');
__PACKAGE__->many_to_many(uses => 'bridges', 'use');

sub relationship_hash {
    return {
        uses => {
            source => 'Use',
            link_source => 'Use2Zoning',
            ref_to_parent => 'zoning',
            ref_to_related => 'use',
            stop_edit => 1,
            class_widget => sub {
                my ($self, $children) = @_;
                my $has = $self->{row}->uses($self);
                for my $obj (@$children) {
                    $has->{$obj->id} = 1;
                }
                my @objs;
                for my $obj ($self->{row}->plan->uses) {
                    next if $has->{$obj->id};
                    push @objs, $obj;
                }
                return drop_down(name => 'use', objs => \@objs);
            }
        },
    }
}

1;
