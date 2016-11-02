package SmartSea::Schema::Result::Dataset;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('data.datasets');
__PACKAGE__->add_columns(qw/id name custodian contact desc data_model is_a_part_of is_derived_from license attribution disclaimer path unit/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(custodian => 'SmartSea::Schema::Result::Organization');
__PACKAGE__->belongs_to(data_model => 'SmartSea::Schema::Result::DataModel');
__PACKAGE__->belongs_to(is_a_part_of => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(is_derived_from => 'SmartSea::Schema::Result::Dataset');
__PACKAGE__->belongs_to(license => 'SmartSea::Schema::Result::License');
__PACKAGE__->belongs_to(unit => 'SmartSea::Schema::Result::Unit');

sub long_name {
    my ($self) = @_;
    my $name = "'".$self->name."'";
    my $rel = $self->is_a_part_of;
    if ($rel) {
        $name .= " of '".$rel->long_name."'";
    }
    $rel = $self->is_derived_from;
    if ($rel) {
        $name .= " from '".$rel->long_name."'";
    }
    return $name;
}

sub as_HTML_data {
    my ($self) = @_;

    my @data;

    my @l;
    push @l, [li => [[b => 'custodian'],[1 => " = ".$self->custodian->name]]] if $self->custodian;
    if ($self->contact) {
        my $c = $self->contact;
        # remove email
        $c =~ s/\<.+?\>//;
        push @l, [li => [[b => "contact"],[1 => " = ".$c]]];
    }
    push @l, [li => [[b => "description"],[1 => " = ".$self->desc]]] if $self->desc;
    push @l, [li => [[b => "disclaimer"],[1 => " = ".$self->disclaimer]]] if $self->disclaimer;
    push @l, [li => [[b => "license"],[1 => " = "],a($self->license->name, $self->license->url)]] if $self->license;
    push @l, [li => [[b => "attribution"],[1 => " = ".$self->attribution]]] if $self->attribution;
    push @l, [li => [[b => "data model"],[1 => " = ".$self->data_model->name]]] if $self->data_model;
    push @l, [li => [[b => "unit"],[1 => " = ".$self->unit->name]]] if $self->unit;
    push @data, [ul => \@l] if @l;

    my $rel = $self->is_a_part_of;
    if ($rel) {
        push @data, [h2 => "'".$self->name."' is a part of '".$rel->name."'"];
        push @data, $rel->as_HTML_data;
    }
    $rel = $self->is_derived_from;
    if ($rel) {
        push @data, [h2 => "'".$self->name."' is derived from '".$rel->name."'"];
        push @data, $rel->as_HTML_data;
    }

    return @data;

}

sub a {
    my ($link, $url) = @_;
    return [a => $link, {href=>$url}];
}

1;
