package CAD::Drawing::Calculate;
our $VERSION = '0.10';

use CAD::Drawing;
use CAD::Drawing::Defined;
use CAD::Drawing::Calculate::Finite;

our @ISA = qw(
	CAD::Drawing::Calculate::Finite
	);

use CAD::Calc qw(
	dist2d
	line_intersection
	);

use Math::Vec qw(NewVec);

use vars qw(
	@orthfunc
	);

use strict;
use Carp;
########################################################################
=pod

=head1 NAME

CAD::Drawing::Calculate -- Calculations for CAD::Drawing

=head1 DESCRIPTION

This module provides calculation functions for the CAD::Drawing family
of modules.

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
  CAD::Calc
  Math::Vec

=cut
########################################################################

=head1 Methods

=cut
########################################################################

=head2 OrthExtents

Calculates the extents of a group of objects (selected according to select_addr()) and returns an array: [xmin,xmax],[ymin,ymax].

  @extents = $drw->OrthExtents(\%opts);

=cut
sub OrthExtents {
	my $self = shift;
	my($opts) = @_;
	my $retref = $self->select_addr($opts);
	my @worklist = @{$retref};
	my(@xvals, @yvals);
	foreach my $addr (@worklist) {
		my ($xdata, $ydata) = $self->EntOrthExtents($addr);
		push(@xvals, @$xdata);
		push(@yvals, @$ydata);
	}
	@xvals = sort({$a<=>$b} @xvals);
	@yvals = sort({$a<=>$b} @yvals);
	return([ $xvals[0], $xvals[-1] ], [$yvals[0], $yvals[-1] ] );
} # end subroutine OrthExtents definition
########################################################################

=head2 getExtentsRec

Alias to OrthExtents() which returns a polyline-form array of points
(counter clockwise from lower-left) describing a rectangle.

  @rec = $drw->getExtentsRec(\%opts);

=cut
sub getExtentsRec {
	my $self = shift;
	my($opts) = @_;
	my ($x, $y) = $self->GetOrth_extents($opts);
	return( 
		[$x->[0], $y->[0]],
		[$x->[1], $y->[0]],
		[$x->[1], $y->[1]],
		[$x->[0], $y->[1]],
		);
} # end subroutine getExtentsRec definition
########################################################################

=head2 EntOrthExtents

Gets the orthographic extents of the object at $addr

  @extents = $drw->EntOrthExtents($addr);

=cut
sub EntOrthExtents {
	my $self = shift;
	my ($addr) = @_;
	my $obj = $self->getobj($addr);
	# FIXME: this will only get the point items
	my $stg = $call_syntax{$addr->{type}}[1];
	my ($xpts, $ypts) = $orthfunc[0]{$stg}->($obj->{$stg});
} # end subroutine EntOrthExtents definition
########################################################################

=head2 @orthfunc

List of hash references containing code references to reduce
duplication and facilitate natural flow (rather than ifififif
statements.)

=cut

@orthfunc = (
	{ # stage one hash ref
		"pt" => sub {
			my($pt) = @_;
			return([$pt->[0]], [$pt->[1]]);
		}, # end subroutine $orthfunc[0]{pt} definition
		"pts" => sub {
			my($pts) = @_;
			my @vals = ([], []);
			for(my $i = 0; $i < @$pts; $i++) {
				foreach my $c (0,1) {
					push(@{$vals[$c]}, $pts->[$i][$c]);
				}
			}
			return(@vals);
		}, # end subroutine $orthfunc[0]{pts} definition
	}, # end stage one hash ref
	{ # stage two hash ref
		# FIXME: here we put the fun stuff about rad and text
	}, # end stage two hash ref
); # end @orthfunc bundle
########################################################################

=head2 offset

Intended as any-object offset function (not easy).

$dist is negative to offset outward

  $drw->offset($dist);

=cut
sub offset {
	carp("no offset function yet");
} # end subroutine offset definition
########################################################################

=head2 divide

  $drw->divide();

=cut
sub divide {
	carp("no divide function yet");
} # end subroutine divide definition
########################################################################

=head2 pline_to_ray

Transforms a polyline with a nubbin into a ray (line with direction.)

  $line_addr = $drw->pline_to_ray($pline_addr);

=cut
sub pline_to_ray {
	my $self = shift;
	my ($pl_addr) = @_;
	($pl_addr->{type} eq "plines") || carp("not a polyline");
	my @pts = $self->Get("pts", $pl_addr);
	(@pts == 3) || croak("not 3 points to polyline");
#	print "checking: ", dist2d($pts[0], $pts[1]) ,
#						"<=>", 
#						dist2d($pts[1], $pts[2]), 
#			"\n";
	my $dir = dist2d($pts[0], $pts[1]) <=> dist2d($pts[1], $pts[2]);
	($dir > 0) || (@pts = reverse(@pts));
	my $obj = $self->getobj($pl_addr);
	my %lineopts = (
		"layer" => $pl_addr->{layer},
		"color" => $obj->{color},
		"linetype" => $obj->{linetype},
		);
	return($self->addline([@pts[0,1]], \%lineopts) );
} # end subroutine pline_to_ray definition
########################################################################

=head2 trim_both

Trims two lines to their intersection.

  $drw->trim_both($addr1, $addr2);

=cut
sub trim_both {
	my $self = shift;
	my @items = (shift,shift);
	my @lines;
	my @vecs;
	my @mids;
	foreach my $item (@items) {
		$item or die "no item\n";
		my @pts = $self->Get("pts", $item);
#        @pts or die "problem with $item\n";
		# print "points: @{$pts[0]}, @{$pts[1]}\n";
		my $vec = NewVec(NewVec(@{$pts[1]})->Minus($pts[0]));
		my $mid = [NewVec($vec->ScalarMult(0.5))->Plus($pts[0])];
		push(@mids, $mid);
		push(@vecs, $vec);
		push(@lines, [@pts]);
	}
	my @int = line_intersection(@lines);
	defined($int[0]) or return();
#    print "making vec from @int\n";
	my $pt = NewVec(@int);
#    print "got point: @$pt\n";
	foreach my $i (0,1) {
		my $dot = $vecs[$i]->Dot([$pt->Minus($mids[$i])]);
		# print "dot product: $dot\n";
		# if the dot product is positive, 
		#   intersection is in front of midpoint.
		my $end = ($dot > 0);
		# print "end is $end\n";
		$lines[$i][$end]  = $pt;
		$self->Set({pts => $lines[$i]}, $items[$i]);
	}

	return($pt);

	

} # end subroutine trim_both definition
########################################################################
########################################################################
1;