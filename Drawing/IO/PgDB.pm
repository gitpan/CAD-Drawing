package CAD::Drawing::IO::PgDB;
our $VERSION = '0.01';

use CAD::Drawing;
use CAD::Drawing::Defined;

use DBI;
use Storable qw(freeze);
use Digest::MD5 qw(md5);

use strict;
use Carp;

########################################################################
=pod

=head1 NAME

CAD::Drawing::IO::PgDB -- PostgreSQL save / load methods

=head1 NOTICE

This module is considered pre-ALPHA and under-documented.  Its use is
strongly discouraged except under experimental conditions.  Particularly
susceptible to change will be the table structure of the database, which
currently does not yet even have any auto-create method.

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
	DBI
	DBD::Pg

=cut
########################################################################

=head1 Back-End Input and output methods

The functions load() and save() are responsible for determining the
filetype (with forced types available via $opt->{type}.)  These then
call the appropriate load<thing> or save<thing> functions.

=cut
########################################################################

=head2 loaddb

Loads a CAD::Drawing object from an SQL database.  $spec should be of
the form required by the database driver.

$opts->{auth} = ["username", "password"] may be required to create a
connection.

  $drw->loaddb($spec, $opts);

=cut
sub loaddb {
	my $self = shift;
	my ($spec, $options) = @_;
	my %opts = parse_options($spec, $options);
	my $dbh = DBI->connect(
		$opts{spec}, $opts{username}, $opts{password},
		) or croak("connection failed\n");
	my %have = map( {$_ => 1} $dbh->tables);
	$have{drawing} or croak("$spec has no drawing table");
	$have{layer} or croak("$spec has no layer table");
	my $drawing = $opts{drawing};
	my $col = $dbh->selectcol_arrayref(
					"select layer_name from layer where dwg_name=?", 
										{}, $drawing) or 
					croak "get layers failed";
	my @layers = @$col;
	@layers or croak "no layers for $drawing";
	# print "got layers:\n\t", join("\n\t", @layers), "\n";
	my($s, $n) = check_select(\%opts);
	my %sth;
	my $ftchdbg = 0; # for fetch debugs
	my $stat = $opts{show_stat};
	foreach my $layer (@layers) {
		$stat && print "layer $layer\n";
		$s->{l} && ($s->{l}{$layer} || next);
		$n->{l} && ($n->{l}{$layer} && next);
		if($have{arcs}) {
			# load them
			$sth{arcs} || ($sth{arcs} = 
				$dbh->prepare(
					"SELECT " . join(", ",
									"a.arc_id",
									"a.x_value",
									"a.y_value",
									"a.z_value",
									"a.radius",
									"a.stang",
									"a.endang",
									"a.color",
									"a.linetype",
									) . " " .
					"FROM layer l, arcs a " .
					"WHERE a.layer_id = l.layer_id " .
					"AND l.dwg_name = ?" .
					"AND l.layer_name = ?")
					);
			my $success = $sth{arcs}->execute($drawing, $layer);
			my $arcs = $sth{arcs}->fetchall_arrayref;
			foreach my $ar (@$arcs) {
				my ($id, $x, $y, $z, $r, $sa, $ea, $co, $lt) = @$ar;
				$ftchdbg && print "fetching arc $id\n";
				($stat > 1) && print "arc\n";
				my %aropts = (
						"color"    => $co,
						"layer"    => $layer,
						"linetype" => $lt,
						"id"       => $id,
						);
				my @angs = ($sa, $ea);
				my $addr = $self->addarc([$x,$y,$z], $r, \@angs, {%aropts});
				} # end foreach $ar
			}
		if($have{circles}) {
			# load these
			$sth{circles} || ($sth{circles} =
				$dbh->prepare(
					"SELECT " . join(", ",
									"c.circle_id",
									"c.x_value",
									"c.y_value",
									"c.z_value",
									"c.radius",
									"c.color",
									"c.linetype",
									) . " " .
					"FROM layer l, circles c " .
					"WHERE c.layer_id = l.layer_id " .
					"AND l.dwg_name = ?" .
					"AND l.layer_name = ?")
					);
			my $success = $sth{circles}->execute($drawing, $layer);
			my $circles = $sth{circles}->fetchall_arrayref;
			foreach my $ci (@$circles) {
				my($id, $x,$y,$z,$r,$co,$lt) = @$ci;
				$ftchdbg && print "fetching circle $id\n";
				($stat > 1) && print "circle\n";
				my %ciopts = (
						"color"    => $co,
						"layer"    => $layer,
						"linetype" => $lt,
						"id"       => $id,
						);
				my $addr = $self->addcircle([$x,$y,$z], $r, {%ciopts});
				} # end foreach $ci
			} # end if $have{circles}
		if($have{lines}) {
			# load these
			$sth{lines} || ($sth{lines} =
				$dbh->prepare(
					"SELECT " . join(", ",
									"s.line_id",
									"s.x1_value",
									"s.y1_value",
									"s.z1_value",
									"s.x2_value",
									"s.y2_value",
									"s.z2_value",
									"s.color",
									"s.linetype",
									) . " " .
					"FROM layer l, lines s " .
					"WHERE s.layer_id = l.layer_id " .
					"AND l.dwg_name = ?" .
					"AND l.layer_name = ?")
					);
			my $success = $sth{lines}->execute($drawing, $layer);
			my $lines = $sth{lines}->fetchall_arrayref;
			foreach my $li (@$lines) {
				my($id, $x1,$y1,$z1, $x2,$y2,$z2, $co, $lt) = @$li;
				$ftchdbg && print "fetching line $id\n";
				($stat > 1) && print "line\n";
				my %liopts = (
						"color"    => $co,
						"layer"    => $layer,
						"linetype" => $lt,
						"id"       => $id,
						);
				my @pts = (
						[$x1, $y1, $z1],
						[$x2, $y2, $z2]
						);
				my $addr = $self->addline(\@pts, {%liopts});
				} # end foreach $li
			} # end if $have{lines}
		if($have{points}) {
			# load these
				# FIXME: don't have any of these yet
			}
		if($have{polyline}) {
			# load these
			$sth{plines} || ($sth{plines} =  
				$dbh->prepare(
					"SELECT " . join(", ", 
								"p.line_id", 
								"p.line_value", 
								"p.sclosed", 
								"p.color", 
								"p.linetype"
								) . " " . 
					"FROM  layer l, polyline p " .
					"WHERE p.layer_id = l.layer_id " .
					"AND l.dwg_name = ?".
					"AND l.layer_name = ?")
					);
			my $success = $sth{plines}->execute($drawing, $layer);
			my $plines = $sth{plines}->fetchall_arrayref;
			# print "fetching polylines for $layer from $drawing\n";
			# print "got polylines:\n\t", 
			# 	join("\n\n\t", map({join(" ", @{$_})} @{$plines})), "\n";
			foreach my $pl (@{$plines}) {
				my ($id, $lv, $cl, $co, $lt) = @{$pl};
				$ftchdbg && print "fetching polyline $id\n";
				($stat > 1) && print "polyline\n";
				print "closed: $cl\n";
				my %plopts = (
						"closed"   => $cl,
						"color"    => $co,
						"layer"    => $layer,
						"linetype" => $lt,
						"id"       => $id,
						);
				my @pts = map({[split(/\s*,\s*/, $_)]
							} split(/\s*:\s*/, $lv)
							);
				#print "got points:\n\t", 
				#	join("\n\t", map({join(",", @{$_})} @pts)), "\n";
				my $addr = $self->addpolygon(\@pts, {%plopts});	
				} # end foreach $pl
			} # end if $have{polyline}
		if($have{"3Dplines"}) {
		
			# I'm not sure that we really want to implement these in the
			# same way as the others.  Are 3Dplines really any different
			# than your run-of-the-mill polylines?  If you just load 3D
			# coordinates into a polyline, it will mostly act like a 3D
			# polyline until you try to save to and from autocad format.
			# Given that we have already made the decision to move away
			# from that, let it be simple everywhere else.

		} # end if $have{3Dplines}
		if($have{texts}) {
			# load these
			$sth{texts} || ($sth{texts} = 
				$dbh->prepare(
					"SELECT " . join(", ",
								"t.text_id",
								"t.x_value",
								"t.y_value",
								"t.z_value",
								"t.height",
								"t.text_string",
								"t.color",
								"t.linetype",
								) . " " .
					"FROM layer l, texts t " .
					"WHERE t.layer_id = l.layer_id " .
					"AND l.dwg_name = ? " . 
					"AND l.layer_name = ? ")
					);
			my $success = $sth{texts}->execute($drawing, $layer);
			my $texts = $sth{texts}->fetchall_arrayref;
			foreach my $te (@{$texts}) {
				($stat > 1) && print "text\n";
				my ($id, $x, $y, $z, $h, $str, $co, $lt) = @$te;
				my %teopts = (
						"height"   => $h,
						"color"    => $co,
						"layer"    => $layer,
						"linetype" => $lt,
						"id"       => $id,
						);
				my $addr = $self->addtext([$x,$y,$z], $str, {%teopts});
				} # end foreach $te
			} # end if $have{texts}
		if($have{inst_point} and $have{data_point} ) {
			# FIXME: I currently just load these as if they were
			# FIXME:  typical points
			$sth{inst_points} || ($sth{inst_points} = 
				$dbh->prepare(
					"SELECT " . join(", ",
								"i.match_id",
								"d.x_value",
								"d.y_value",
								"d.z_value",
								"i.color",
								"i.linetype",
								) . " " .
					"FROM layer l, inst_point i, data_point d " .
					"WHERE i.layer_id = l.layer_id " .
					"AND l.dwg_name = ?" .
					"AND l.layer_name = ?" .
					"AND i.point_id = d.point_id")
					);
			my $success = $sth{inst_points}->execute($drawing, $layer);
			my $points = $sth{inst_points}->fetchall_arrayref;
			foreach my $po (@{$points}) {
				($stat > 1) && print "point\n";
				my ($id, $x, $y, $z, $co, $lt) = @$po;
				my %poopts = (
						"color"    => $co,
						"layer"    => $layer,
						"linetype" => $lt,
						"id"       => $id,
						);
				my $addr = $self->addpoint([$x,$y,$z], {%poopts});
				# print "point:  $x,$y,$z\n";
				} # end foreach $po
			} # end if $have{points}
		} # end foreach $layer
		
	
	$dbh->disconnect();
} # end subroutine loaddb definition
########################################################################

=head2 savedb

  $drw->savedb($spec, $opts);

=cut
sub savedb {
	my $self = shift;
	my ($spec, $options) = @_;
	my %opts = parse_options($spec, $options);
	my $drawing = $opts{drawing};
	my %dbopts;
	$opts{dbopts} && (%dbopts = %{$opts{dbopts}});
	defined($dbopts{AutoCommit}) || ($dbopts{AutoCommit} = 0);
	my $dbh = DBI->connect(
		$opts{spec}, $opts{username}, $opts{password},
		\%dbopts
		) or croak("connection failed\n");
	# FIXME: # we could make the required tables (add this later?)
	my %have = map( {$_ => 1} $dbh->tables);
	$have{drawing} or croak("$spec has no drawing table");
	$have{layer} or croak("$spec has no layer table");

	# FIXME: we need to support selective saves here? 

	# FIXME: 
	# should also have a way to kill deleted items (would have to get
	# everything from this database for this drawing, then remove it
	# (which frees us to always INSERT (but prevents building-up a
	# drawing from separate processes)
	
	# FIXME: should have more info to select drawing name
	my ($had) = $dbh->selectrow_array(
		"SELECT dwg_name from drawing where dwg_name = ?",
		{},
		$drawing
		);
	print "table had: $had\n";
	if($had) {
		# FIXME: this is currently pointless
		my $did = $dbh->do(
			"UPDATE drawing set dwg_name = ? " .
				"WHERE dwg_name = ?", 
			{
			AutoCommit => 1,
			},
			$drawing, $drawing
			);
	}
	else {
#        print "insert forced\n";
		$dbh->do(
			"INSERT into drawing(dwg_name) VALUES(?)",
			{},
			$drawing
			) or croak("cannot make drawing", $dbh->errstr);
	}
	

	# Seems like a better plan to simply use REPLACE, but also offer an
	# option to delete all existing items first (rather than doing all
	# of the queries and then a few deletes

	# This would be fine and dandy except that REPLACE is a proprietary
	# extension implemented only by mysql

	my @layers = $self->getLayerList();
#    print "layers: @layers\n";
	my $to_save = $self->select_addr($options);
#    print "not a list: @$to_save\n";
	my %se_h; # SELECT handles
	my %up_h; # UPDATE handles
	my %in_h; # INSERT handles
	$se_h{layers} =	$dbh->prepare(
					"SELECT layer_id " .
					"FROM layer " .
					"WHERE layer_name = ? " .
					"AND dwg_name = ? " 
				);
	$in_h{layers} = $dbh->prepare(
					"INSERT into layer(layer_name, dwg_name) " .
					"VALUES(?, ?)"
				);
	my %tntr = (
		"arcs" => "arcs",
		"circles" => "circles",
		"lines" => "lines",
		"plines" => "polyline", # FIXME: rename that table!
		"points" => "points",
		"texts" => "texts",
		"images" => "images",
		);

	my %del_h;
	foreach my $type (keys(%tntr)) {
		$have{$tntr{$type}} || next; # no table for that
		$del_h{$type} = $dbh->prepare(
			"DELETE from " . $tntr{$type} . " " .
			"WHERE layer_id = ?"
			);
	}
	# make it the default behaviour to cleanup first
	defined($opts{clear_layers}) || ($opts{clear_layers} = 1);
					
	foreach my $layer (@layers) {
#        print "working on layer $layer\n";
		$se_h{layers}->execute($layer, $drawing)
			or croak("cannot lookup $layer in $drawing\n");
		my ($layer_id) = $se_h{layers}->fetchrow_array();
		if(defined($layer_id)) {
			# FIXME: would set layer properties here
#            print "layer id: $layer_id\n";
			if($opts{clear_layers}) {
#                print "clearing layer $layer\n";
				foreach my $type (keys(%del_h)) {
#                    print "clearing type $type\n";
					$del_h{$type}->execute($layer_id);
#                    print "affecting ", $del_h{$type}->rows, " rows\n";
					$del_h{$type}->finish();
				}
			}
		}
		else {
#            print "should be making new layer\n";
			$in_h{layers}->execute($layer, $drawing);
			# nothing beats maintaining knowledge in 5 places!
			# FIXME:  SQL is primitive?
			my ($this) = $se_h{layers}->execute($layer, $drawing)
				or croak("cannot lookup $layer in $drawing\n");
#            print "this came back as $this\n";
			($layer_id) = $se_h{layers}->fetchrow_array();
#            print "new layer_id: $layer_id\n";
		}
		my %these = sort_addr($layer, $to_save);
		# FIXME: current assumption is that the tables exist!
		foreach my $point (@{$these{points}}) {
#            print "have a point\n";
			my $obj = $self->getobj($point);
			# FIXME: this crap has GOT to go elsewhere
			$se_h{points} || ( 
				$se_h{points} = 
					$dbh->prepare(
						"SELECT point_id " .
						"FROM points " .
						"WHERE point_id = ? ". 
						"AND layer_id = ? "
						)
					);
			$in_h{points} || (
				$in_h{points} = 
					$dbh->prepare(
						"INSERT into points(" .
							join(", ", 
								"x_value",
								"y_value",
								"z_value",
								"color",
								"linetype",
								"layer_id",
								) . 
							") " .
						"VALUES(?,?,?, ?,?, ?)"
						)
					);
			$up_h{points} || (
				$up_h{points} =
					$dbh->prepare(
						"UPDATE points set " .
							join(", ", 
								map({"$_ = ?"}
									"x_value",
									"y_value",
									"z_value",
									"color",
									"linetype",
									)
								) . 
						"WHERE layer_id = ? " .
						"AND point_id = ?"
						)
					);
			my $id = $point->{id};
			$se_h{points}->execute($id, $layer_id);
			my ($have_id) = $se_h{points}->fetchrow_array;
			# FIXME: this will eventually have to change to a name!
			if(defined($have_id)) {
#                print "replacing $id\n";
				# over-write it
				$up_h{points}->execute(
					$obj->{pt}[0], $obj->{pt}[1], $obj->{pt}[2],
					$obj->{color}, $obj->{linetype},
					$layer_id, $id
					);
			}
			else {
#                print "new for $id\n";
				# make a new one
				$in_h{points}->execute( 
					$obj->{pt}[0], $obj->{pt}[1], $obj->{pt}[2],
					$obj->{color}, $obj->{linetype},
					$layer_id
					);
			}
		} # end foreach $point
		foreach my $line (@{$these{lines}}) {
		} # end foreach $line
		foreach my $pline (@{$these{plines}}) {
			my $obj = $self->getobj($pline);
			$se_h{plines} || (
				$se_h{plines} = 
					$dbh->prepare(
						"SELECT line_id " .
						"FROM polyline " .
						"WHERE line_id = ? " .
						"AND layer_id = ? "
						)
					);
			$in_h{plines} || (
				$in_h{plines} = 
					$dbh->prepare(
						"INSERT into polyline(" .
							join(", ",
								"line_value", "sclosed",
								"color", "linetype",
								"layer_id"
								) .
							") " .
						"VALUES(?, ?, ?,?, ?)"
						)
					);
			$up_h{plines} || (
				$up_h{plines} = 
					$dbh->prepare(
						"UPDATE polyline set " .
							join(", ", 
								map({"$_ = ?"}
									"line_value", "sclosed",
									"color", "linetype",
									"layer_id"
									) 
								) .
						"WHERE layer_id = ? " .
						"AND line_id = ? "
						)
					);
			my $pstring = join(":", map({join(",", @$_)} @{$obj->{pts}}));
#            print "closed: $obj->{closed}\n";
			my @tr = ("f", "t");
			my $id = $pline->{id};
			$se_h{plines}->execute($id, $layer_id);
			my ($have_id) = $se_h{plines}->fetchrow_array;
			if(defined($have_id)) {
				$up_h{plines}->execute( 
					$pstring, $tr[$obj->{closed}],
					$obj->{color}, $obj->{linetype},
					$layer_id, $id
					);
			}
			else {
				$in_h{plines}->execute(
					$pstring, $tr[$obj->{closed}],
					$obj->{color}, $obj->{linetype},
					$layer_id
					);
			}
		} # end foreach $pline
		foreach my $circ (@{$these{circs}}) {
		} # end foreach $circ
		foreach my $arc (@{$these{arcs}}) {
		} # end foreach $arc
		foreach my $text (@{$these{texts}}) {
		} # end foreach $text
	} # end foreach $layer
	$se_h{layers}->finish();
	$in_h{layers}->finish();
	foreach my $type (keys(%call_syntax)) {
		$se_h{$type} && $se_h{$type}->finish();
		$in_h{$type} && $in_h{$type}->finish();
		$up_h{$type} && $up_h{$type}->finish();
	}
	unless($dbopts{AutoCommit}) {
		$dbh->commit or 
			croak("commit failed:\n", $dbh->errstr);
	}
	$dbh->disconnect();
} # end subroutine savedb definition
########################################################################

=head1 Internals

=cut
########################################################################

=head2 parse_options

Allows options to come in through the $spec or %opts.

  %options = parse_options($spec, \%opts);

=cut
sub parse_options {
	my ($spec, $options) = @_;
	my %opts;
	(ref($options) eq "HASH" ) && (%opts = %$options);
	$opts{auth} && ( 
		($opts{username}, $opts{password}) = @{$opts{auth}}
		);
	unless($opts{drawing}) {
		if($spec =~ s/drawing=(.*?)//) {
			$opts{drawing} = $1;
			$spec =~ s/;+/;/;
			$spec =~ s/;$//;
			}
		else {
			croak("no drawing found in spec or opts\n");
			}
		}
	$opts{spec} = $spec;
	return(%opts);
} # end subroutine parse_options definition
########################################################################

=head2 sort_addr

Sorts through @addr_list and returns a hash of array references for each
entity type.

  %these = sort_addr($layer, \@addr_list);

=cut
sub sort_addr {
	my ($layer, $list) = @_;
#    print "list: @$list\n";
	my @valid = grep({$_->{layer} eq $layer} @$list);
	my @ents = sort(keys(%call_syntax));
	# init the refs
	my %these = map({$_ => []} @ents);
	foreach my $addr (@valid) {
		push(@{$these{$addr->{type}}}, $addr);
	}
	return(%these);
} # end subroutine sort_addr definition
########################################################################

1;