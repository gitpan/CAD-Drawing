package CAD::Drawing::IO;
our $VERSION = '0.20';

use CAD::Drawing;
use CAD::Drawing::Defined;

use CAD::Drawing::IO::OpenDWG;
use CAD::Drawing::IO::PostScript;
use CAD::Drawing::IO::Image;
use CAD::Drawing::IO::PgDB;
use CAD::Drawing::IO::Circ;
use CAD::Drawing::IO::Tk;

use Stream::FileInputStream;
use Compress::Zlib;
use File::Temp qw(tempfile unlink0);
use Storable;

our @ISA = qw(
	CAD::Drawing::IO::OpenDWG
	CAD::Drawing::IO::PostScript
	CAD::Drawing::IO::Image
	CAD::Drawing::IO::PgDB
	CAD::Drawing::IO::Circ
	CAD::Drawing::IO::Tk
	);

use strict;
use Carp;
########################################################################
=pod

=head1 NAME 

CAD::Drawing::IO -- I/O methods for the CAD::Drawing module

=head1 Description

This module provides the load() and save() functions for CAD::Drawing
and provides a point of flow-control to deal with the inheritance and
other trickiness of having multiple formats handled through a single
module.

=head1 AUTHOR

  Eric L. Wilhelm
  ewilhelm at sbcglobal dot net
  http://pages.sbcglobal.net/mycroft

=head1 COPYRIGHT

This module is copyright (C) 2003 by Eric L. Wilhelm and A. Zahner Co.

=head1 LICENSE

This module is distributed under the same terms as Perl.  See the Perl
source package for details.

You may use this software under one of the following licenses:

  (1) GNU General Public License
    (found at http://www.gnu.org/copyleft/gpl.html)
  (2) Artistic License
    (found at http://www.perl.com/pub/language/misc/Artistic.html)

=head1 NO WARRANTY

This software is distributed with ABSOLUTELY NO WARRANTY.  The author
and his employer will in no way be held liable for any loss or damages
resulting from its use.

=head1 Modifications

The source code of this module is made freely available and
distributable under the GPL or Artistic License.  Modifications to and
use of this software must adhere to one of these licenses.  Changes to
the code should be noted as such and this notification (as well as the
above copyright information) must remain intact on all copies of the
code.

Additionally, while the author is actively developing this code,
notification of any intended changes or extensions would be most helpful
in avoiding repeated work for all parties involved.  Please contact the
author with any such development plans.


=head1 SEE ALSO

  CAD::Drawing
  CAD::Drawing::IO::*

=cut
########################################################################

=head1 front-end Input and output methods

The functions load() and save() are responsible for determining the
filetype (with forced types available via $opt->{type}.)  These then
call the appropriate load<thing> or save<thing> functions.

=cut
########################################################################

=head2 save

Saves a file to disk.  See the save<type> functions in this file and the
other filetype functions in the CAD::Drawing::IO::<type> modules.

See each save<type> function for available options for that type.

While you may call the save<type> function directly (if you include the
module), it is recommended that you stick to the single point of
interface provided here.

Note that this method also implements forking.

  $drw->save($filename, \%options);

=cut
sub save {
	my $self = shift;
	my ( $filename, $opt) = @_;
	my $type = $$opt{type};
	if($$opt{forkokay}) {
		$SIG{CHLD} = 'IGNORE';
		my $kidpid;
		if($kidpid = fork) {
			return($kidpid);
		}
		defined($kidpid) or die "cannot fork $!\n";
		$$opt{forkokay} = 0;
		$self->diskaction("save", $filename, $type, $opt);
		exit;
	}
	return($self->diskaction("save", $filename, $type, $opt));
} # end subroutine save definition
########################################################################

=head2 load

Loads a file from disk.  See the load<type> functions in this file and
the other filetype functions in the CAD::Drawing::IO::<type> modules.

See each load<type> function for available options for that type.

In most cases %options may contain the selection methods available via
the CAD::Drawing::check_select() function.

While you may call the load<type> function directly (if you include the
module), it is recommended that you stick to the single point of
interface provided here.

  $drw->load($filename, \%options);

=cut
sub load {
	my $self = shift;
	my ($filename, $opt) = @_;
	my $type = $$opt{type};
	return($self->diskaction("load", $filename, $type, $opt));
} # end subroutine load definition
########################################################################

=head1 Back-End functions

You should not need to call these directly, though extensions will need
to be added to the flow control of these two functions.

=cut

=head2 diskaction

This function is for internal use, intended to consolidate the type
selection and calling of load/save methods.

  $drw->diskaction("load|save", $filename, $type, \%options);

=cut
sub diskaction {
my $self = shift;
	my ($action, $filename, $type, $opt) = @_;
	my %opts;
	(ref($opt) eq "HASH") && (%opts = %$opt);
	($action =~ m/save|load/) || 
			carp("Cannot access disk with action:  $action\n");
	($type) || 
			($type = typelookup($filename) );
	# choose filetype:
	if($type =~ m/(dxf)|(dwg)/i) {
		($action eq "save") && 
					return($self->savedwg( $filename, {%opts, type => $type}));
		($action eq "load") && return($self->loaddwg( $filename, $opt));
		}
	elsif($type eq "postscript") {
		($action eq "save") && return($self->saveps($filename, $opt));
		($action eq "load") && return($self->loadps($filename, $opt));
		}
	elsif($type eq "image") {
		($action eq "save") && return($self->saveimg($filename, $opt) );
		($action eq "load") && return($self->loadimg($filename, $opt) );
		}
	elsif($type eq "gzip") {
		($action eq "save") && return($self->savegzip($filename, $opt) );
		($action eq "load") && return($self->loadgzip($filename, $opt) );
		}
	elsif($type eq "DB") {
		($action eq "save") && return($self->savedb($filename, $opt));
		($action eq "load") && return($self->loaddb($filename, $opt));
		}
	elsif($type eq "circ") {
		($action eq "save") && return($self->savecirc($filename, $opt));
		($action eq "load") && return($self->loadcirc($filename, $opt));
		}
	else {
		croak("I don't know how to $action \"$type\" type files yet\n");
		}
} # end subroutine diskaction definition
########################################################################

=head2 typelookup

Internally selects file type based on extensions.  While you should
never need to call this function directly, you may want understand how
it works if you are trying to do something strange.

  $type = typelookup($filename);

=cut

# FIXME: may need to send $self here:

sub typelookup {
	my ($filename) = @_;
	my $extension;
	###print "lookup on $filename\n";
	###(-d "$filename") && print "is directory\n";
	if($filename =~ m/^dbi:/) {
		return("DB");
		}
	elsif($filename =~ m/.*\.(\w+)$/) {
		$extension = $1;
		}
	elsif( (-d $filename) && (-e "$filename/$dirtag") ) {
		# what to assume here?
		croak("no support for directory files yet");
		}
	elsif( (-d $filename) && (-e "$filename/$circtag")) {
		return("circ");
		}
	else {
		croak("filename has no extension and no type specified\n");
		}
	$extension = lc($extension);
	($extension eq "gz") && 
		return("gzip");
	($extension eq "dwg") && 
		return("dwg2000");
	($extension eq "dxf") && 
		return("dxf2000");
	($extension eq "ps") && 
		return("postscript");
	($extension =~ m/tif|gif|jpg|png|bmp|eps|fax|fig|pict|psd|xcf/) &&
		return("image");
	carp("couldn't determine type from extension\n");
	return($extension);
} # end subroutine typelookup definition
########################################################################

=head1 Compressed I/O functions

These use File::Temp and compression modules to create a compressed version of most supported I/O types (need tar support for directory-based formats?)

=cut

=head2 savegzip

  $drw->savegzip($filename, \%opts);

=cut
sub savegzip {
	my $self = shift;
	my($filename, $opt) = @_;
	my $suffix = $filename;
	$suffix =~ s/^.*(\..*)\.gz$/$1/;
	$suffix = ".drwpm" . $suffix;
	my($fh, $tmpfilename) = tempfile(SUFFIX => $suffix);
	$loaddebug && print "tempfile is named:  $tmpfilename\n";
	close($fh);
	my $returnval = $self->save($tmpfilename, $opt);
	print "temp save complete\n";
	my $stream = Stream::FileInputStream->new( $tmpfilename);
	my $string = Compress::Zlib::memGzip( $stream->readAll );
	defined($string) || croak("compression failed\n");
	unlink0($fh, $tmpfilename) or 
							croak("failed to unlink $tmpfilename\n");
	$fh = FileHandle->new;
	open($fh, ">$filename") or croak("can't write to $filename\n");
	print $fh $string;
	$fh->close;
	return($returnval);
} # end subroutine savegzip definition
########################################################################

=head2 loadgzip

  $drw->loadgzip($filename, \%opts);

=cut
sub loadgzip {
	my $self = shift;
	my($filename, $opt) = @_;
	my $stream = Stream::FileInputStream->new( $filename);
	my $string = Compress::Zlib::memGunzip( $stream->readAll);
	defined($string) || croak("decompression failed\n");
	my $suffix = $filename;
	$suffix =~ s/^.*(\..*)\.gz$/$1/;
	$suffix = ".drwpm" . $suffix;
	my($fh, $tmpfilename) = tempfile(SUFFIX => $suffix);
	$loaddebug && print "tempfile is named:  $tmpfilename\n";
	print $fh $string;
	$fh->close();
	my $returnval = $self->load($tmpfilename, $opt);
	unlink0($fh, $tmpfilename) or 
							croak("failed to unlink $tmpfilename\n");
	return($returnval);
} # end subroutine loadgzip definition
########################################################################
1;