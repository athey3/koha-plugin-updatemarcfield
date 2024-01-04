package Koha::Plugin::Com::SacFSC::UpdateMarcField;

use Modern::Perl;
use utf8;

use base qw(Koha::Plugins::Base);

use C4::Auth;
use C4::Biblio qw/ModBiblio GetFrameworkCode/;
use C4::Context;

use Koha::Biblios;
use Koha::Items;
use Koha::UploadedFiles;

use MARC::Record;
use MARC::Field;
use Text::CSV;
use Storable 'dclone';

our $VERSION = "1.0.00";

our $metadata = {
    name            => 'Update Marc Field',
    author          => "Chales L. Athey III, derived from Tomás Cohen Arazi's AddURLstoMarc",
    description     => 'Tool for replacing and updating Field in Marc records',
    date_authored   => '2023-11-19',
    date_updated    => '2024-01-03',
    minimum_version => '22.0500000',
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    my $step = $cgi->param('step') // 'welcome';

    if ( $step eq 'welcome' ) {
        $self->tool_step_welcome;
    } elsif ( $step eq 'results' ) {

        # $self->tool_step_results;
        $self->tool_step_results;
    } elsif ( $step eq 'diff' ) {

        #$self->show_diff;
        $self->show_diff;
    } elsif ( $step eq 'cancel' ) {
        $self->tool_step_cancel;
    } elsif ( $step eq 'apply' ) {
        $self->tool_step_apply;
    } else {

        # $step eq 'render'
        $self->tool_step_results;
    }
}

sub tool_step_welcome {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'tool-step-welcome.tt' } );

    if ( $args->{'error'} ) {
        $template->param( error => $args->{'error'} );
    }

    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub tool_step_results {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template;

    my $id = $cgi->param('uploadedfileid');
    my $fh = Koha::UploadedFiles->find($id)->file_handle;

    my $all_updates = _read_csv($fh);

    my $good_rows;
    my $bad_rows;

    foreach my $biblionumber ( keys %{$all_updates} ) {

        my $biblio = Koha::Biblios->find($biblionumber);
        if ( defined $biblio ) {

            # biblio exists
            $good_rows->{$biblionumber}->{updates} = $all_updates->{$biblionumber};
            $good_rows->{$biblionumber}->{title}   = $biblio->title // '';
        } else {

            # biblio doesn't exist
            $bad_rows->{$biblionumber}->{updates} = $all_updates->{$biblionumber};
        }
    }

    close $fh;

    $template = $self->get_template( { file => 'tool-step-results.tt' } );
    $template->param(
        good_rows      => $good_rows,
        bad_rows       => $bad_rows,
        uploadedfileid => $id
    );

    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub tool_step_apply {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template;

    my $id            = $cgi->param('uploadedfileid');
    my $uploaded_file = Koha::UploadedFiles->find($id);
    my $fh            = $uploaded_file->file_handle;

    my $all_updates = _read_csv($fh);

    my $good_rows;
    my $bad_rows;

    foreach my $biblionumber ( keys %{$all_updates} ) {

        my $biblio = Koha::Biblios->find($biblionumber);
        if ( defined $biblio ) {

            # biblio exists
            # Get the MARC record as Koha does
            my $record = $biblio->metadata->record;
            my $fw     = GetFrameworkCode( $biblio->biblionumber );

            my $modified_record = $record->clone();
            _add_urls( $modified_record, $all_updates->{$biblionumber} );

            ModBiblio( $modified_record, $biblio->biblionumber, $fw );
        } else {

            # biblio doesn't exist
            $bad_rows->{$biblionumber}->{updates} = $all_updates->{$biblionumber};
        }
    }

    close $fh;
    $uploaded_file->delete;

    $template = $self->get_template( { file => 'tool-step-final.tt' } );
    $template->param(
        bad_rows       => $bad_rows,
        uploadedfileid => $id
    );

    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub tool_step_cancel {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $id = $cgi->param('uploadedfileid');

    Koha::UploadedFiles->find($id)->delete
        if defined $id;

    my $template = $self->get_template( { file => 'tool-step-welcome.tt' } );

    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub show_diff {

    my $self = shift;
    my $cgi  = $self->{cgi};

    my $biblionumber = $cgi->param('biblionumber');
    my $id           = $cgi->param('uploadedfileid');

    my $fh = Koha::UploadedFiles->find($id)->file_handle;

    my $all_updates = _read_csv($fh);
    my $updates     = $all_updates->{$biblionumber};

    my $record          = Koha::Biblios->find($biblionumber)->metadata->record;
    my $modified_record = $record->clone();
    _add_urls( $modified_record, $updates );

    my $template = $self->get_template( { file => 'marc-diff.tt' } );
    $template->param(
        BIBLIONUMBER    => $biblionumber,
        MARC_FORMATTED1 => $record->as_formatted,
        MARC_FORMATTED2 => $modified_record->as_formatted,
        uploadedfileid  => $id
    );

    print $cgi->header( -charset => 'utf-8' );
    print $template->output();

}

sub _read_csv {
    my ($fh) = shift;

    my $updates;

    my $csv = Text::CSV->new( { binary => 1 } )    # should set binary attribute.
        or die "Cannot use CSV: " . Text::CSV->error_diag();
	#$csv->column_names(qw( biblionumber url text ));
	#$csv->getline_hr($fh);                         #drop the first line

	# First better be "biblionumber"
	# Rest should be subfield name, eg. url is "u", link text is "y"
	my @cols = @{ $csv->getline($fh) };
	$csv->column_names(@cols);

    while ( my $row = $csv->getline_hr($fh) ) {
		my $item_ref = dclone $row;
		delete $item_ref->{biblionumber};
        push @{ $updates->{ $row->{biblionumber} } }, $item_ref;
		#			{ u => $row->{u}, y => $row->{y} };
    }

    $csv->eof or $csv->error_diag();
    close $fh;

    return $updates;
}

sub _add_urls {
    my ( $record, $updates ) = @_;

    # Check if we need to delete the matching fields first, do so
	foreach my $update ( @{$updates} ) {
		if ( exists($update->{criteria}) &&
			( $update->{criteria} ne "" ) &&
			exists($update->{criteria_subfield}) &&
			( $update->{criteria_subfield} ne "" ) ) {
			my $criteria = $update->{criteria};
			my @subfields = $record->field($update->{data_field});
			foreach my $subfield (@subfields) {
				my $crit_subfield = $subfield->subfield($update->{criteria_subfield});
				if ( $crit_subfield =~ m/$criteria/ ) {
					$record->delete_fields($subfield);
				}
			}
		}
	}
    # Actually add the URLs
	foreach my $update ( @{$updates} ) {
        _add_url( $record, $update );
	}
}

sub _add_url {
    my ( $record, $update ) = @_;
	my $item_ref = dclone $update;
	#my $field = MARC::Field->new( '856', $ind1, '', u => $url);

	my $data_field = $item_ref->{data_field};
    my $ind1 = $item_ref->{ind1};
	my $ind2 = $item_ref->{ind2};
	my $criteria = $item_ref->{criteria};
	my $criteria_subfield = $item_ref->{criteria_subfield};

	# Delete items that dont get put in subfield record
	delete $item_ref->{data_field};
	delete $item_ref->{ind1};
	delete $item_ref->{ind2};
	delete $item_ref->{criteria};
	delete $item_ref->{criteria_subfield};

	# Delete empty hash entries

	while ( my ($key, $value ) = each %{ $item_ref } ) {
		delete $item_ref->{$key} unless ( $value ne "" );
	}
	# If hash is empty just return
	if ( (scalar keys %{$item_ref}) <= 1 ) {
		return;
	}

	#	Have to have at least one subfield in initial new request
	#	Just use the first in the hash

	my $first_subfield = ( sort keys %{ $item_ref } ) [0];
	my $first_subfield_value = $item_ref->{$first_subfield};
	delete $item_ref->{$first_subfield};

	my $field = MARC::Field->new( $data_field, $ind1, $ind2,
		$first_subfield => $first_subfield_value );

	#loop over other subfields
	while ( my($key, $value) = each %{ $item_ref } ){
		if (defined $value and length $value) {
			$field->add_subfields( "$key" =>  "$value" );
		}
	}
    $record->insert_fields_ordered($field);
}

sub instsall {
	my ( $self, $args ) = @_;
	return 1;
}

sub uninstall {
	my ( $self, $args ) = @_;
	return 1;
}

1;
