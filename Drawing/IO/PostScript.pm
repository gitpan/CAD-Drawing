package CAD::Drawing::IO::PostScript;
our $VERSION = '0.01';

use CAD::Drawing;
use CAD::Drawing::Defined;

use strict;
use Carp;
########################################################################
=pod

=head1 NAME

CAD::Drawing::IO::PostScript -- PostScript output methods

=head1 Description

I would like this module to both load and save PostScript vector
graphics, but I have not yet found a suitable PostScript parsing
package.

=head1 NOTICE

This module should be considered pre-ALPHA and untested.

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
  PostScript::Simple

=cut

########################################################################
=head1 Methods

=cut

=head2 loadps

  loadps();

=cut
sub loadps {
	croak("cannot yet load postscript!");
} # end subroutine loadps definition
########################################################################

=head2 saveps

  $drw->saveps($filename, \%opts);

=cut
sub saveps {
	my $self = shift;
	my($filename, $opt) = @_;
	my %opts;
	my $accuracy = 1; # digits of accuracy with which to bother
	my $sp = 30;
	(ref($opt) eq "HASH") && (%opts = %$opt);
	my $outobj;
	unless($opts{"readymadeobject"} ) {
		$outobj = new PostScript::Simple(
						landscape => 1,
						eps => 0,
						papersize => "Letter",
						colour => 1,
						);
		$outobj->newpage;
		}
	else {
		$outobj = $opts{"readymadeobject"};
		}

	# now can get the size from the object and use it to set the scale of
	# things
	my(@fitsize) = ($$outobj{bbx2}, $$outobj{bby2});
#   print "got size:  @fitsize\n";
 	my(@bound) = ([0,0], [@fitsize]);
	my $drw = $self;  # default is to smash $self
	
	# FIXME: why did I have this here?
	# my $worklist = $drw->select_addr();
	
	unless($opts{"noclone"}) {
		$drw = Drawing->new;
		# passing original opts allows selective save
		$self->GroupClone($drw, $opt);	
		}
	####################################################################
	# Setup border
	my @border;
	if(ref($opts{"border"}) eq "ARRAY") {
#		@border = ( [@sp] , [$fitsize[0]-$sp[0] , $fitsize[1]-$sp[1] ]);
		@border = @{$opts{"border"}};
		}
	elsif(defined($opts{"border"})) {
		my $num = $opts{"border"};
		@border = ([$num,$num], [-$num,-$num]);
		}
	else {
		@border = ([$sp, $sp], [-$sp, -$sp]);
		}
	####################################################################
	# Perform fit
# 	$outobj->line(0,0, @fitsize);
	my $scaling = $drw->fit_to_bound([@bound], [@border], 
							{"center" =>[$fitsize[0] / 2, $fitsize[1]/2 ] , %opts} );
	####################################################################
	if($opts{"show border"} ) {
		$drw->addrec( 
				[ 
					[
					$bound[0][0] + $border[0][0] / 2 , 
					$bound[0][1] + $border[0][1] / 2
					],
					[
					$bound[1][0] + $border[1][0] / 2  , 
					$bound[1][1] + $border[1][1] / 2
					]
				]
			);
		} # end if show border
	# now must draw all of the resultant geometry
	my $filledopt = 0;
	if($opts{"filled"}) {
		# FIXME:  need some way to make this selective?
		$filledopt = $opts{filled};
		}
	my $font_choice = "Helvetica";
	$opts{font} && ($font_choice = $opts{font});
	# NOTE NOTE NOTE NOTE NOTE NOTE:not using $self here!

} # end subroutine saveps definition
########################################################################

=head2 PostScript::Simple::setpscolor

  PostScript::Simple::setpscolor();

=cut
sub PostScript::Simple::setpscolor {
	my $self = shift;
	my($ac_color) = @_;
	my %no = map( { $_ => 1} 0, 7, 256);
	$no{$ac_color} && return();
	my $ps_color = $aci2rgb[$ac_color];
	$self->setcolour(@$ps_color);
} # end subroutine PostScript::Simple::setpscolor definition
########################################################################

1;