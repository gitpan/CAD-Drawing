package CAD::Drawing::IO::Circ;
our $VERSION = '0.01';

use CAD::Drawing;
use CAD::Drawing::Defined;

use strict;
use Carp;
########################################################################
=pod

=head1 NAME

CAD::Drawing::IO::Circ -- load and save for circle data

=head1 NOTICE

This module and the format upon which it relies should be considered extremely experimental and should not be used in production except under short-term and disposable conditions.

=head1 INFO

This module is intended only as a backend to CAD::Drawing::IO.  The only
method from here which you may want to call directly is pingcirc(),
which will return information stored in the ".circ_data" file.

For loading and saving, please use the front-end interface provided by
load() and save() in CAD::Drawing::IO.

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

=cut
########################################################################

=head1 Methods


=cut

=head2 loadcirc

  $drw->loadcirc($directory, $opts);

=cut
sub loadcirc {
	my $self = shift;
	my ($directory, $opts) = @_;
	my $info = $self->pingcirc($directory) or croak("no $circtag file");
	# FIXME: add $info somewhere to toplevel of $self
	my $suffix = $info->{suffix};
	my ($s, $n) = check_select($opts);
	foreach my $file (glob("$directory/*$suffix")) {
		my $layer = $file;
		$layer =~ s#^$directory/*##;
		$layer =~ s/$suffix$//;
		# print "$file -> $layer\n";
		$s->{l} && ($s->{l}{$layer} || next);
		$n->{l} && ($n->{l}{$layer} && next);
		open(CIRCLESIN, $file); 
		while(my $line = <CIRCLESIN>) {
			my($ids,$cord,$r,$co,$lt) = split(/\s*:\s*/, $line);
			$s->{c} && ($s->{c}{$co} || next);
			$n->{c} && ($n->{c}{$co} && next);
			my %addopts = (
					layer=>$layer,
					color=>$co, 
					linetype=>$lt,
					id=>$ids
					);
			my @pt = split(/\s*,\s*/, $cord);
			$self->addcircle(\@pt, $r, {%addopts});
			} # end while reading file
		} # end foreach $file

} # end subroutine loadcirc definition
########################################################################

=head2 savecirc

  $drw->savecirc();

=cut
sub savecirc {
	my $self = shift;
	my ($directory, $opts) = @_;

} # end subroutine savecirc definition
########################################################################

=head2 pingcirc

Returns a hash reference for colon-separated key-value pairs in the
".circ_data" file which is found inside of $directory.  If the file is
not found, returns undef. 

The key may not contain colons.  Colons in values will be preserved
as-is.

  $drw->pingcirc($directory);

=cut
sub pingcirc {
	my $self = shift;
	my ($directory) = @_;
	open(TAG, "$directory/$circtag") or return();
	my %info;
	foreach my $line (<TAG>) {
		$line =~ s/\s+$//;
		# keys may not contain colons, but values can
		# whitespace around first colon is optional
		my ($key, $val) = split(/\s*:\s*/, $line, 2);
		$info{$key} = $val;
		}
	close(TAG);
	return(\%info);
} # end subroutine pingcirc definition
########################################################################


1;