package CAD::Calc;
our $VERSION = '0.20';

use Math::Vec qw(NewVec);
# this gets the OffsetPolygon routine (which still needs work)
use Math::Geometry::Planar;
use Math::Geometry::Planar::Offset;

use vars qw($precision $pi);
$precision = 7;
$pi = atan2(1,1) * 4;

require Exporter;
@ISA='Exporter';
@EXPORT_OK = qw (
	distdivide
	subdivide
	shorten_line
	dist
	dist2d
	signdist
	offset
	isleft
	unitleft
	line_intersection
	);

	
use strict;
use Carp;
=pod

=head1 NAME

CAD::Calc -- generic cad-related geometry calculations

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


=cut
########################################################################
=head1 Functions

These are all exported as options.

=cut
########################################################################

=head2 distdivide

Returns a list of point references resulting from dividing $line into
as many parts as possible which are at least $dist apart.

  @points = distdivide(\@line, $dist);

=cut
sub distdivide {
	my($line, $dist) = @_;
	$dist or croak("call to distdivide would cause divide by zero");
	my $ptA = NewVec(@{$line->[0]});
	my $ptB = NewVec(@{$line->[1]});
	my $seg = NewVec($ptB->Minus($ptA));
	my $length = $seg->Length();
	# optionally go for fewer points here?
	my $count = $length / $dist;
	$count = int($count);
	return(subdivide($line, $count));
} # end subroutine distdivide definition
########################################################################

=head2 subdivide

Returns a list of point references resulting from subdividing $line
into $count parts.  The list will be $count-1 items long, (does not
include $line->[0] and $line->[1]);

$line is of the form:  [ [x1, y1, z1], [x2, y2, z2] ] where z1 and z2
are optional.

  @points = subdivide($line, $count);

=cut
sub subdivide {
	my ($line, $count) = @_;
	$count || croak("cannot divide line into zero segments");
	my $ptA = NewVec(@{$line->[0]});
	my $ptB = NewVec(@{$line->[1]});
# 	print "line:  @$ptA -- @$ptB\n";
	my $seg = NewVec($ptB->Minus($ptA));
	my @points;
	for(my $st = 1; $st < $count; $st++) {
		push(@points, [$ptA->Plus( [ $seg->ScalarMult($st / $count) ] ) ] );
		}
	return(@points);
} # end subroutine subdivide definition
########################################################################

=head2 shorten_line

Shortens the line by the distances given in $lead and $tail.

  @line = shorten_line(\@line, $lead, $tail);

=cut
sub shorten_line {
	my ($line, $lead, $tail) = @_;
	my $ptA = NewVec(@{$line->[0]});
	my $ptB = NewVec(@{$line->[1]});
# 	print "line:  @$ptA -- @$ptB\n";
	my $seg = NewVec($ptB->Minus($ptA));
	my $len = $seg->Length();
	($lead + $tail >= $len) && return();
#        croak("CAD::Calc::shorten_line($lead, $tail)\n" .
#                "\t creates inverted line from length: $len\n");
	return(
		[$ptA->Plus([$seg->ScalarMult($lead / $len)])],
		[$ptB->Minus([$seg->ScalarMult($tail / $len)])],
		);
} # end subroutine shorten_line definition
########################################################################

=head2 dist

Returns the direct distance from ptA to ptB.

  dist($ptA, $ptB);

=cut
sub dist {
	my($ptA, $ptB) = @_;
	(ref($ptB) eq "ARRAY") || ($ptB = [0,0,0]);
	my $dist = sqrt(
		($ptB->[0] - $ptA->[0]) ** 2 +
		($ptB->[1] - $ptA->[1]) ** 2 +
		($ptB->[2] - $ptA->[2]) ** 2
		);
	return($dist);
} # end subroutine dist definition
########################################################################

=head2 dist2d

Purposefully ignores a z (2) coordinate.

  dist2d($ptA, $ptB);

=cut
sub dist2d {
	my($ptA, $ptB) = @_;
	# print "ref is: ", ref($ptB), "\n";
	(ref($ptB) eq "ARRAY") || ($ptB = [0,0,0]);
	# print "ptB: @{$ptB}\n";
	my $dist = sqrt(
		($ptB->[0] - $ptA->[0]) ** 2 +
		($ptB->[1] - $ptA->[1]) ** 2
		);
	return($dist);
} # end subroutine dist2d definition
########################################################################

=head2 signdist

Returns the signed distance

  signdist(\@ptA, \@ptB);

=cut
sub signdist {
	my ($ptA, $ptB) = @_;
	my $b = NewVec(@{$ptB});
	return($b->Minus($ptA));
} # end subroutine signdist definition
########################################################################

=head2 offset

Creates a contour representing the offset of @polygon by $dist.
Positive distances are inward when @polygon is ccw.

  @polygons = offset(\@polygon, $dist);

=cut
sub offset {
	my ($polygon, $dist) = @_;
	my @pgons = OffsetPolygon($polygon, $dist);
	return(@pgons);
} # end subroutine offset definition
########################################################################

=head2 intersection_data

Calculates the two numerators and the denominator which are required
for various (seg-seg, line-line, ray-ray, seg-ray, line-ray, line-seg)
intersection calculations.

  ($k, $l, $d) = intersection_data(\@line, \@line);

=cut
sub intersection_data {
	my @l = @_;
	my $n1 = Determinant(
		$l[1][0][0]-$l[0][0][0],
		$l[1][0][0]-$l[1][1][0],
		$l[1][0][1]-$l[0][0][1],
		$l[1][0][1]-$l[1][1][1],
		);
	my $n2 = Determinant(
		$l[0][1][0]-$l[0][0][0],
		$l[1][0][0]-$l[0][0][0],
		$l[0][1][1]-$l[0][0][1],
		$l[1][0][1]-$l[0][0][1],
		);
	my $d  = Determinant(
		$l[0][1][0]-$l[0][0][0],
		$l[1][0][0]-$l[1][1][0],
		$l[0][1][1]-$l[0][0][1],
		$l[1][0][1]-$l[1][1][1],
		);
	return($n1, $n2, $d);

} # end subroutine intersection_data definition
########################################################################

=head2 line_intersection

Returns the intersection point of two lines.

  @pt = line_intersection(\@line, \@line);

=cut
sub line_intersection {
	my @l = @_;
	foreach my $should (0,1) {
		# print "should have $should\n";
		# print $l[$should], "\n";
		(ref($l[$should]) eq "ARRAY") or warn "not good\n";
	}
	my ($n1, $n2, $d) = intersection_data(@l);
	if($d == 0) {
		# print "parallel!\n";
		return(); # parallel
	}
	my @pt = (
		$l[0][0][0] + $n1 / $d * ($l[0][1][0] - $l[0][0][0]),
		$l[0][0][1] + $n1 / $d * ($l[0][1][1] - $l[0][0][1]),
		);
	print "got point: @pt\n";
	return(@pt);
} # end subroutine line_intersection definition
########################################################################

=head2 Determinant

  Determinant($x1, $y1, $x2, $y2);

=cut
sub Determinant {
	my ($x1,$y1,$x2,$y2) = @_;
	return($x1*$y2 - $x2*$y1);
} # end subroutine Determinant definition
########################################################################

=head2 pgon_angles

Returns the angle of each edge of polygon in xy plane.

Not functioning

  @angles = pgon_angles(@points);

=cut
sub pgon_angles {
	my (@points)  = @_;
	warn "this is unfinished";
	my @angles = (0) x scalar(@points);
	print "number of angles: @angles\n";
	for(my $i = -1; $i < $#points; $i++) {
		my $start = NewVec(@{$points[$i]});
	}
	

} # end subroutine pgon_angles definition
########################################################################

=head2 isleft

Returns positive if @point is left of @line.

  isleft(\@line, \@point);

=cut
sub isleft {
	my ($line, $pt) = @_;
	my $isleft = ($line->[1][0] - $line->[0][0]) * 
					($pt->[1] - $line->[0][1]) -
				 ($line->[1][1] - $line->[0][1]) *
				 	($pt->[0] - $line->[0][0]);
	return($isleft);
} # end subroutine isleft definition
########################################################################

=head2 unitleft

Returns a unit vector which is perpendicular and to the left of @line.
Purposefully ignores any z-coordinates.

  $vec = unitleft(@line);

=cut
sub unitleft {
	my (@line) = @_;
	my $ln = NewVec(
			NewVec(@{$line[1]}[0,1])->Minus([@{$line[0]}[0,1]])
			);
	$ln = NewVec($ln->UnitVector());
	my $left = NewVec($ln->Cross([0,0,-1]));
	my $isleft = isleft(\@line, [$left->Plus($line[0])]);
# 	print "fact said $isleft\n";
	return($left);
} # end subroutine unitleft definition
########################################################################










########################################################################

1;