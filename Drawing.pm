package CAD::Drawing;
our $VERSION = '0.10';

# This code is copyright 2003 Eric L. Wilhelm and A. Zahner Co.
# See below for licensing details.

use strict;
use Carp;

use CAD::Drawing::Defined;
use CAD::Drawing::Manipulate;
use CAD::Drawing::Calculate;
use CAD::Drawing::IO;

our @ISA = qw(
	CAD::Drawing::Manipulate
	CAD::Drawing::Calculate
	CAD::Drawing::IO
	);

#use Fcntl;
#use MLDBM qw(SDBM_File Storable);

########################################################################
=pod

=head1 NAME

CAD::Drawing -- Methods to create, load, and save vector graphics

=head1 SYNOPSIS

The primary intention of this module is to provide high-level operations
for creating, loading, saving and manipulating vector graphics without
having to be overly concerned about smile floormats.

=item The syntax of this works something like the following:

A simple example of a file converter:

  use CAD::Drawing;
  $drw = CAD::Drawing->new;
  $drw->load("file.dwg");
  $drw->save("file.ps");

This is a very basic example, and will barely scratch the surface of
this module's capabilities.  See the details for each function below and
in the documentation for the backend modules.

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

These modules are required by Drawing.pm and will be automatically
included by the single I<use> Drawing; statement.  No functions are
exported to the main program's namespace (unless you try to use
CAD::Drawing::Defined from your main code (don't do that.))

  CAD::Drawing::Manipulate
  CAD::Drawing::Defined
  CAD::Drawing::Calculate
  CAD::Drawing::Calculate::Finite
  CAD::Drawing::IO
  CAD::Drawing::IO::OpenDWG
  CAD::Drawing::IO::PostScript
  CAD::Drawing::IO::Image

While it might be problematic to have to install a huge tree worth of
modules just to use one, from a programming and design standpoint, it is
much easier to deal with so much code when it is broken into separate
pieces.  Additionally, all of the backend IO modules are optional
(though the use statements aren't setup that way (anyone want to setup a
Makefile.PL that will take care of this?))

Each backend module may have additional requirements of its own.

=cut
########################################################################

=head1 Constructor

=head2 new

Returns a blessed reference to a new CAD::Drawing object.

  $drw = CAD::Drawing->new(%options);

%options becomes a part of the data structure, so be careful what you
%ask for, because you'll get it (I check nothing!)

=item Currently useful options:

=item nocolortrack => 1

Disables loading of colortrack hash (breaking select by color methods,
but saving a few milliseconds of time on big drawings.)

=item isbig => 1

Stores geometry data in package global variables (one per object.)  This
allows programs to exit more quickly, but will result in memory leaks if
used inside of a loop. Do not use this option if you expect the memory
used by the object to be freed when it goes out of scope.

The rule of thumb is: 

  my $drw = CAD::Drawing->new(); # lexically scoped (in a loop or sub)
	or
	$drw = CAD::Drawing->new(isbig=>1); # $main::drw 

=cut

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;
	my $self = {@_};
	if($self->{isbig}) {
		# this is clunky, but saves -_#*HUGE*#_- on big drawings!
		$CAD::Drawing::geometry_data{$self} = {};
		$self->{g} = $CAD::Drawing::geometry_data{$self};
		$CAD::Drawing::color_tracking{$self} = {};
		$self->{colortrack} = $CAD::Drawing::color_tracking{$self};
		delete($self->{isbig});
		}
	bless($self, $class);
	return($self);
} # end subroutine new definition
########################################################################

=head1 add functions

All of these take a small set of required arguments and a reference to
an options hash.

The standard options are as follows:

  layer     => $layername
  color     => $color (as name or number (0-256))
  linetype  => $linetype (marginally supported in most formats)
  id        => $id	

=cut

=head2 addline

Add a line between @pts.  No special options.

  @pts = ([$x1, $y1], [$x2, $y2]);
  $drw->addline(\@pts, \%opts);

=cut
sub addline {
	my $self = shift;
	my ($points, $opts) = @_;
	(scalar(@$points) == 2) or carp("cannot draw line without 2 points");
	my $obj;
	($obj, $opts) = $self->setdefaults("lines", $opts);
	## print ref($obj), " keys: ", join(" ", keys(%{$obj})), "\n";
	## print "$obj->{addr}{layer}\n";
#    print "pretty color:  $obj->{color}\n";
	$obj->{pts} = [map({[@{$_}]} @$points)];
	return($obj->{addr});
} # end subroutine addline definition
########################################################################

=head2 addpolygon

Add a polyline through (2D) @points.

  %opts = ( closed => BOOLEAN );
  $drw->addpolygon(\@points, \%opts);

=cut
sub addpolygon {
	my $self = shift;
	my ($points, $opts) = @_;
	(scalar(@$points) > 1) or carp("cannot draw pline without 2 or more points");
	my $obj;
	($obj, $opts) = $self->setdefaults("plines", $opts);
	$obj->{pts} = [map({[@{$_}]} @$points)];
	unless(defined($opts->{closed})) {
		($#$points > 1) && ($obj->{closed} = 1);
		}
	return($obj->{addr});
} # end subroutine addpolygon definition
########################################################################

=head2 addrec

A shortcut to addpolygon. Specify the opposite corners with @rec, which
will look like a diagonal line of the rectangle.

  @rec = ( [$x1, $y1], [$x2, $y2] );

  $drw->addrec(\@rec, $opts);

=cut
sub addrec {
	my $self = shift;
	my ($rec, $opts) = @_;
	(ref($opts) eq "HASH") || ($opts = {});
	my @rec = @$rec;	# expect this to be of the form:  ([x,y],[x,y])
	my @points = (
				[ $rec[0][0], $rec[0][1] ],
				[ $rec[1][0], $rec[0][1] ],
				[ $rec[1][0], $rec[1][1] ],
				[ $rec[0][0], $rec[1][1] ]
				);
	$opts->{closed} = 1; # sounds fair
	return($self->addpolygon(\@points, $opts) );
} # end subroutine addrec definition
########################################################################

=head2 addtext

Adds text $string at @pt.  Height should be specified in $opts{height},
which may contain font and other options in the future.

  $drw->addtext(\@pt, $string, \%opts);

=cut
sub addtext {
	my $self = shift;
	my ($point, $string, $opts) = @_;
	my ($obj) = $self->setdefaults("texts", $opts);
	$obj->{pt} = [@$point];
	$obj->{string} = $string;
	# If I let setdefaults pass all options into $obj,
	#	I don't even have to worry about them here!
	$obj->{height} || ($obj->{height} = 1);
	return($obj->{addr});
} # end subroutine addtext definition
########################################################################

=head2 addtextlines

Returns @addr_list for new entities.

Similar to the syntax of addtext() , but @point is the insert point for
the top line.  The %opts hash should contain at least 'height' and
'spacing', and can also include 'layer', 'color', and 'linetype' (but
defaults can be automatically set for all of these.)

  $drw->addtextlines(\@point, "string\nstring\n", \%opts);

=cut
sub addtextlines {
	my $self = shift;
	my($point, $string, $opts) = @_;
	my @point = @$point;
	(ref($opts) eq "HASH") || ($opts = {});
	$opts = {%$opts}; # deref as much as possible
	my($height, $spacing) = (1, 1.67);
	$opts->{height} || ($opts->{height} = $height);
	if($opts->{spacing}) {
		$spacing = $opts->{spacing};
		delete($opts->{spacing});
		}
	my $y = $point[1];
	my @retlist;
	foreach my $line (split(/\015?\012/, $string)) {
		if($line) {
			push(@retlist, $self->addtext([$point[0], $y], $line, $opts));
			}
		$y -= $spacing * $height;
		}
	return(@retlist);
} # end subroutine addtextlines definition
########################################################################

=head2 addtexttable

  $drw->addtexttable();

=cut
sub addtexttable {
	my $self = shift;
	my($point, $table, $opts) = @_;
	my @point = @$point;
	my @table = @$table;
	my %opts;
	(ref($opts) eq "HASH") && (%opts = %$opts);
	my @spaces = @{$opts{spaces}};
	delete($opts{spaces});
	my $length = scalar(@spaces);
	my @tcols;
	for(my $col = 0; $col < $length; $col++) {
		push(@tcols, join("\n", map({$_->[$col]} @table)));
		}
	my $x = $point[0];
	my @pts = map({$x+=$_;[$x, $point[1]]} @spaces);
	my @retlist;
	for(my $col = 0; $col < @tcols; $col++) {
		my $ad = $self->addtextlines($pts[$col], $tcols[$col], \%opts);
		push(@retlist, $ad);
		}
	return(@retlist);
} # end subroutine addtexttable definition
########################################################################

=head2 addpoint

  $drw->addpoint(\@pt, \%opts);

=cut
sub addpoint {
	my $self = shift;
	my ($point, $opts) = @_;
	my ($obj) = $self->setdefaults("points", $opts);
	# print "saw:  @$point\n";
	$obj->{pt} = [@$point];
	return($obj->{addr});
} # end subroutine addpoint definition
########################################################################

=head2 addcircle

  $drw->addcircle(\@pt, $rad, \%opts);

=cut
sub addcircle {
	my $self = shift;
	my ($point, $rad, $opts) = @_;
	my ($obj) = $self->setdefaults("circles", $opts);
	$obj->{pt} = [@$point];
	$obj->{rad} = $rad;
	return($obj->{addr});
} # end subroutine addcircle definition
########################################################################

=head2 addarc

  $drw->addarc(\@pt, $rad, \@angs, \%opts);

=cut
sub addarc {
	my $self = shift;
	my ($point, $rad, $angs, $opts) = @_;
	my ($obj) = $self->setdefaults("arcs", $opts);
	$obj->{pt} = [@$point];
	$obj->{rad} = $rad;
	$angs = [@$angs];
	checkarcangs($angs);
	$obj->{angs} = $angs;
	return($obj->{addr});
} # end subroutine addarc definition
########################################################################

=head2 addimage

  $drw->addimage();

=cut
sub addimage {
	my $self = shift;
	my ($point, $opts) = @_;
	my ($obj) = $self->setdefaults("images", $opts);
	$obj->{pt} = [@$point];
	if($obj->{clipping}) {
		$obj->{clipping} = [map({[@{$_}]} @{$obj->{clipping}}) ];
		}
	$obj->{vectors} = [map({[@{$_}]} @{$obj->{vectors}}) ];
	$obj->{size} = [@{$obj->{size}}];
	my $name;
	unless($obj->{name}) {
		$name = $obj->{fullpath};
		$name =~ s/.*\\+//;
		$obj->{name} = $name;
		}
	my $layer = $obj->{addr}{layer};
	#print "adding image (name: $obj->{fullpath})\n";
	push(@{$self->{imagetrack}{$layer}{$name}}, $obj->{addr});
	return($obj->{addr});
} # end subroutine addimage definition
########################################################################

=head1 Query Functions

=cut
########################################################################
sub getImgByName {
	my $self = shift;
	my ($layer, $name) = @_;
	if($self->{imagetrack}{$layer}{$name}) {
		my @list = @{$self->{imagetrack}{$layer}{$name}};
		#allow main to assume that there is only one
		$#list || return($list[0]);	
		return(@list);
		}
	else {
		return();
		}
} # end subroutine getImgByName definition
########################################################################

=head2 getLayerList

  @list = $drw->getLayerList(\%opts);

=cut
sub getLayerList {
	my $self = shift;
	my ($opts) = @_;
	my @list;
	@list = keys(%{$self->{g}});
	my $reg = $opts->{matchregex};
	if(ref($reg) eq "Regexp") {
		# print "reg:\n";
		@list = grep(/$reg/, @list);
		}
	return(@list);
} # end subroutine getLayerList definition
########################################################################

=head2 getAddrByLayer

Returns a list of addresses for all objects on $layer.

  @addr_list = $drw->getAddrByLayer($layer);

=cut
sub getAddrByLayer {
	my $self = shift;
	my ($layer) = @_;
	my $list = $self->select_addr({sl=>[$layer]});
	# print "selected @$list addresses\n";
	$#$list || return($list->[0]);
	return(@$list);
} # end subroutine getAddrByLayer definition
########################################################################

=head2 getAddrByType

Returns a list of addresses for $type entities on $layer.

  @list = $drw->getAddrByType($layer, $type);

=cut
sub getAddrByType {
	my $self = shift;
	my ($layer, $type) = @_;
	# my $list = $self->select_addr({sl=>[$layer],st=>[$type]});
	# my @list = @$list;
	# FIXME: is it better to have the speed and scatter this 
	#			data structure all over?
	my @list = map( {
				{layer => $layer, type => $type, id => $_} 
			} keys(%{$self->{g}{$layer}{$type}})
			);
	$#list || return($list[0]);
	return(@list);
} # end subroutine getAddrByType definition
########################################################################

=head2 getAddrByRegex

  @list = $drw->getAddrByRegex($layer, qr/^model\s+\d+$/, $opts);

=cut
sub getAddrByRegex {
	my $self = shift;
	my ($layer, $regex, $opts) = @_;
	my %opts = %$opts;
	(ref($regex) eq "Regexp") || 
			croak("getAddrByRegex needs precompiled regex");
	my @list = $self->getAddrByType($layer, "texts");
	my @out;
	foreach my $addr (@list) {
		my $obj = $self->getobj($addr);
		if($obj->{string} =~ $regex) {
			$opts{"sub"} && ($opts{"sub"}->($obj->{string}, $regex) );
			push(@out, $addr);
			}
		}
	$#out || return($out[0]);
	return(@out);
} # end subroutine getAddrByRegex definition
########################################################################

=head2 getAddrByColor

  @list = $drw->getAddrByColor($layer, $type, $color);

=cut
sub getAddrByColor {
	my $self = shift;
	my ($layer, $type, $color) = @_;
	$self->{nocolortrack} && croak("nocolortrack kills getAddrByColor");
# 	my %select = (
# 		sl=>[$layer],
# 		st=>[$type],
# 		sc=>[$color]
# 		);
# 	my $list = $self->select_addr(\%select);
# 	my @list = @$list;
	$color = color_translate($color);
#    print "looking for $color on $layer for $type\n";
#    print "existing colors: ", 
		join(" ", keys(%{$self->{colortrack}{$layer}{$type}})), "\n";
	my @list;
	if(my $list = $self->{colortrack}{$layer}{$type}{$color}) {
		@list = @$list;
		}
	$#list || return($list[0]);
#    print "returning array\n";
	return(@list);
} # end subroutine getAddrByColor definition
########################################################################

=head2 getEntPoints

Returns the point or points found at $addr as a list.

If the entity has only one point, the list will be (x,y,z), while a
many-pointed entity will give a list of the form ([x,y,z],[x,y,z]...)

  $drw->getEntPoints($addr);

=cut
sub getEntPoints {
	my $self = shift;
	my ($addr) = @_;
	my $obj = $self->getobj($addr);
	#my $obj = $self->{g}{$addr->{layer}}{$addr->{type}}{$addr->{id}};
	if($obj->{pts}) {
		return(map({[@{$_}]} @{$obj->{pts}}));
		}
	elsif($obj->{pt}) {
		return(@{$obj->{pt}});
		}
	else {
		return();
		}
} # end subroutine getEntPoints definition
########################################################################

=head2 Get

Gets the thing from entity found at $addr.

Returns the value of the thing (even if it is a reference) with the
exception of things that start with "p", which will result in a call to
getEntPoints (and return a list.)

  $drw->Get("thing", $addr);

=cut
sub Get {
	my $self = shift;
	my ($req, $addr) = @_;
	($req =~ m/^p(t|oi)/i) && return( $self->getEntPoints($addr));
	($req =~ m/^defin/i) &&	return($self->getobj($addr));
	my $obj = $self->getobj($addr);
	if(defined(my $thing = $obj->{$req})) {
		return($thing);
		}
	else {
		return();
		}
} # end subroutine Get definition
########################################################################

=head2 Set

  $drw->Set(\%items, $addr);

=cut
sub Set {
	my $self = shift;
	my ($items, $addr) = @_;
	my $obj = $self->getobj($addr);
	$obj or croak("no object for that address\n");
	foreach my $key (%{$items}) {
		$obj->{$key} = $items->{$key};
		}
} # end subroutine Set definition
########################################################################

=head1 Internal Functions

=cut
########################################################################

=head2 setdefaults

internal use only

Performs in-place modification on \%opts and creates a new place for an
entity of $type to live on $opt->{layer} with id $opts->{id} (opts are
optional.)

  $drw->setdefaults($type, $opts);

=cut
sub setdefaults {
	my $self = shift;
	my ($type, $opts) = @_;
	(ref($opts) eq "HASH") || ($opts = {});
#	foreach my $key (@defaultkeys) {
#		defined($opts->{$key}) || ($opts->{$key} = $defaults{$key});
#		}
	defined($opts->{layer}) || ($opts->{layer} = $defaults{layer});
	defined($opts->{color}) || ($opts->{color} = $defaults{color});
	defined($opts->{linetype}) || ($opts->{linetype} = $defaults{linetype});
	my $layer = $opts->{layer};
	# FIXME: I do not really like making the color stupid, 
	# FIXME: but this seems to be the best place for it.
	$opts->{color} = color_translate($opts->{color});
	my $color = $opts->{color};
#    print "color: $color\n";
	my $id = $opts->{id};
	unless(defined($id)) {
		$id = 0;
		my $was_id = $id;
		while($self->{g}{$layer}{$type}{$id}) {
			$id = $self->{lastid}{$layer}{$type} + 1;
			($id == $was_id) && $id++;
			$was_id = $id;
#            print "id: $id\n";
		}
		$opts->{id} = $id;
		}
#    print "$layer ($type) id: $id\n";
	$self->{lastid}{$layer}{$type} = $id;
	my %addr = (
			"layer" => $opts->{layer}, 
			"type"	=> $type,
			"id"    => $id,
			);
	# cleanup the options hash:
	delete($opts->{layer});
	delete($opts->{id});
	# print "self: ", join(" ", keys(%{$self->{g}{0}{$type}})), "\n";
#	$self->{colortrack}{$layer}{$type}{$color} || 
#								($self->{colortrack}{$layer}{$type}{$color} = []);


	# FIXME: color could likely be an array index here:
	$self->{nocolortrack} || 
			push(@{$self->{colortrack}{$layer}{$type}{$color}}, \%addr);
	$self->{g}{$layer}{$type}{$id} = {
		"color" => $opts->{color},
		"linetype" => $opts->{linetype},
		"addr" => \%addr,
		%{$opts}, # allows arbitrary options (not sure if this is good)
		};
	# print "self: ", join(" ", keys(%{$self->{g}{0}{$type}})), "\n";
	return($self->{g}{$layer}{$type}{$id}, $opts);
} # end subroutine setdefaults definition
########################################################################

=head2 getobj

Internal use only.

Returns a reference to the entity found at $addr.

  $drw->getobj($addr);

=cut
sub getobj {
	my $self = shift;
	my ($addr) = @_;
	return($self->{g}{$addr->{layer}}{$addr->{type}}{$addr->{id}});
} # end subroutine getobj definition
########################################################################

=head2 remove

  $drw->remove();

=cut
sub remove {
	my $self = shift;
	my ($addr) = @_;
	if($self->{colortrack}) {
		# must find this in the colortrack array:
		# may be a fatal assumption, but find is based on converting
		# a hash reference into a text string
		my $color = $self->Get("color", $addr);
		my $list = 
			$self->{colortrack}{$addr->{layer}}{$addr->{type}}{$color};
		for(my $i = 0; $i < @$list; $i++) {
			if($list->[$i] eq $addr) {
				my $removed = splice(@$list, $i, 1);
#                print "killed color tracking element $i\n";
			}
		}
	}
	delete($self->{g}{$addr->{layer}}{$addr->{type}}{$addr->{id}});

} # end subroutine remove definition
########################################################################

=head2 select_addr

Selects geometric entities from the Drawing object based on the hash
key-value pairs.  Aside from the options supported by check_select()
this also supports the option "all", which, if true, will select all
entities (this is the default if no hash reference is passed.)

  $drw->select_addr(\%opts);

=cut
sub select_addr {
	my $self = shift;
	my ($opt) = @_;
	my @outlist;
	if(ref($opt) eq "ARRAY") {
		return([@$opt]);
		}
	my %opts;
	if(ref($opt) eq "HASH") {
		%opts = %$opt;
		}
	else {
		$opts{all} = 1;
		}
	my ($s, $n);
	$opts{all} || (($s, $n) = check_select(\%opts));
	my @layers_to_check = keys(%{$self->{g}});
	$s->{l} && (@layers_to_check = keys(%{$s->{l}}));
	# print "checking @layers_to_check\n";
	foreach my $layer (@layers_to_check) {
		$n->{l} && ($n->{l}{$layer} && next);
		foreach my $type (keys(%{$self->{g}{$layer}})) {
			# print "$layer $type\n";
			$s->{t} && ($s->{t}{$type} || next);
			$n->{t} && ($n->{t}{$type} && next);
			
			if($s->{c} or $n->{c} or $s->{lt} or $n->{lt}) {
				my @idlist = keys(%{$self->{g}{$layer}{$type}}); 
				if($s->{c} && (! $self->{nocolortrack})) {
					# yes, this is a bit complex, but it will shorten the list
					@idlist = ();
					map({
							push(@idlist, 
								map({$_->{id}} 
									@{$self->{colortrack}{$layer}{$type}{$_}}
									) # end map :)
								)
							} keys(%{$s->{c}})
						); # end map :(
					} # end if we can just grab colortrack list
				foreach my $id ( @idlist ) {
					my %addr = (
							"layer" => $layer,
							"type"  => $type,
							"id"    => $id,
							);
					my $obj = $self->getobj(\%addr);
					my $color = $obj->{color};
					$s->{c} && ($s->{c}{$color} || next);
					$n->{c} && ($n->{c}{$color} && next);
					print "select color: $color\n";
					push(@outlist, \%addr);
					} # end foreach $id
				} # end if select by color or linetype
			else {
				push(@outlist, 
						map({ 
									{"layer" => $layer, 
									"type"  => $type, 
									"id"    => $_ }
								} keys(%{$self->{g}{$layer}{$type}})
								) # end map :)
							); # end push :)
				} # end else
			} # end foreach $type
		} # end foreach $layer
	return(\@outlist);
} # end subroutine select_addr definition
########################################################################



1;