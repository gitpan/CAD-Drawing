package CAD::Drawing::IO::Tk;
our $VERSION = '0.02';

use CAD::Drawing;
use CAD::Drawing::Defined;

use Tk;
use Tk::WorldCanvas;

use vars qw(
	%dsp
	);

use strict;
use Carp;

my %default = (
	width    => 800,
	height   => 600,
	zoom     => "fit",
	);

=pod

=head1 NAME

CAD::Drawing::IO::Tk -- GUI I/O methods for CAD::Drawing

=head1 NOTICE

This module is considered extremely pre-ALPHA and its use is probably
deprecated by the time you read this.

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

  CAD::Drawing::IO
  Tk

=cut

=head1 Methods

There is no constructor for this class, its methods are inherited via
CAD::Drawing::IO

Need to re-structure the entire deal to have its own object which
belongs to the drawing object (or does the drawing object belong to this
object?)  Either way, we need to be able to build-up into interactive
commands (possibly using eval("\$drw->$command"); ?)

=cut

=head2 show

Creates a new window (no options are required.)

  $drw->show(%options);

=item Available Options

  forkokay  => bool         -- Attempt to fork the new window
  window    => MainWindow   -- Use the pre-existing Tk object
  size      => [W,H]        -- Specify window size in pixels
  width     => W            -- alias to size
  height    => H            -- ditto
  center    => [X,Y]        -- Center the drawing at (X,Y)
  scale     => factor       -- Zoom by factor (default to fit)
  bgcolor   => color        -- defaults to "white"

=cut
sub show {
	my $self = shift;
	my %options = @_;
	my $kidpid;
	if($options{forkokay}) {
		$SIG{CHILD} = 'IGNORE';
		if($kidpid = fork()) {
			return($kidpid);
		}
		defined($kidpid) or croak("cannot fork $!\n");
		$options{forkokay} = 0;
	}
	my $mw = $options{window};
	defined($mw) || ($mw = MainWindow->new());
	unless($options{size}) {
		foreach my $item ("width", "height") {
			my $val = $options{$item};
			$val || ($val = $default{$item});
			push(@{$options{size}}, $val);
		}
	}
	$options{bgcolor} || ($options{bgcolor} = "white");
	# FIXME: should have an indication of viewport number?
	$options{title} || ($options{title} = "Drawing");
	$mw->title($options{title});
	my ($w,$h) = @{$options{size}};
########################################################################
#    my $bbox = [-$w, -$h, $w, $h];
#    $options{bbox} = $bbox;
#    my $cnv = $mw->Scrolled(
#                "Canvas", 
#                '-bg' => $options{bgcolor},
#                '-xscrollincrement' => 1,
#                '-yscrollincrement' => 1,
#                '-confine' => 1,
#                '-scrollbars' => "se",
#                '-width' => $options{size}[0],
#                '-height' => $options{size}[1],
#                '-scrollregion' => $bbox,
#                );
#    $cnv->pack('-fill' => 'both', '-expand' => 1, -side => "top");
#    ###################################################################
#    # FIXME: this needs a lot of work
#    push(@{$self->{tk}}, {mainwindow => $mw});
#    my $tkitem = scalar(@{$self->{tk}}) - 1;
#    print "item count: $tkitem\n";
#    push(@{$self->{tk}[$tkitem]{canvas}}, $cnv);
#    # not sure about saving a big list of these
#    ###################################################################
#    $self->tkbindings($mw, $cnv);
#    $options{noclear} || ($cnv->selectClear);
#    $options{items} || ($options{items} = $self->select_addr({all=>1}));
##    print "items: @{$options{items}}\n";
#    $self->fit_to_bound([[0,0],[$w,$h]],
#            [[5,5],[5,5]],
#            {center => [$w / 2, $h/ 2]});
#    $self->Draw($cnv, %options);
#    $self->tksetview($cnv, %options);
##    $cnv->configure(-scrollregion => [-100,-100,100,100]);
########################################################################
	# new method:
#    print "requesting $w x $h\n";
	my $cnv = $mw->WorldCanvas(
				'-bg' => $options{bgcolor},
				'-width' => $options{size}[0],
				'-height' => $options{size}[1],
				);
	$cnv->pack(-fill => 'both', -expand=>1);
	my $stl = $mw->Message(
		-anchor => "sw",
		-width => $w,
		-justify=>"left",
		);
	$stl->pack(-fill => 'x', -expand=>0, -side => "bottom");
# FIXME: cannot just have a simplistic command line, it has to be powerful
#    my $cmd = $mw->Text(
#        -height=> 2,
#        -width => $w,
#        );
#    $cmd->pack(-fill => 'x', -expand=>0, -side => "bottom");
	$self->tkbindings($mw, $cnv, $stl);
	$options{items} || ($options{items} = $self->select_addr({all=>1}));
	$self->Draw($cnv, %options);
	$cnv->viewAll();
	if(defined($kidpid) or $options{hang}) {
	    $mw->MainLoop;
	}
	else {
		return($mw);
	}
} # end subroutine show definition
########################################################################

=head2 Draw

Draws geometry on the Tk canvas $cnv.  List of items to draw must be
specified via addresses stored in $options{items}.

  $drw->Draw($cnv, %options);

=cut
sub Draw {
	my $self = shift;
	my $cnv = shift; 
	my %options = @_;
	my @list = @{$options{items}};
	foreach my $item (@list) {
		my $type = $item->{type};
#        print "item: $type\n";
		if($dsp{$type}) {
			$dsp{$type}->($self, $cnv, $item);
		}
		else {
			carp "no function for $type\n";
		}
	}
	
} # end subroutine Draw definition
########################################################################

=head2 tkbindings

Setup the keybindings.

  $drw->tkbindings($mw, $cnv);

=cut
sub tkbindings {
	my $self = shift;
	my ($mw, $cnv, $stl) = @_;
	# FIXME: this should be much more robust

# maybe a vim-style modal binding? or possibly a command-line based
# system.

	
	$mw->bind('<Any-Enter>' => sub{ $cnv->Tk::focus});

#    $mw->bind('<q>' => sub{$mw->destroy});
#    $cnv->CanvasBind('<q>' => sub{print "called\n";exit;});
	$mw->bind('<q>' => sub {$mw->destroy});
	# mouse-wheel zooming:
	$cnv->CanvasBind('<4>' => sub{$cnv->zoom(1.125)});
	$cnv->CanvasBind('<5>' => sub{$cnv->zoom(1/1.125)});
	# middle-button pan:
	my @pan_start;
	my $drag_current;
	$cnv->CanvasBind(
		'<ButtonPress-2>' => sub {
			@pan_start = $cnv->eventLocation();
#            print "starting pan at @pan_start\n";
		});
	# have to have this here to prevent spurious panning with double-clicks
	$cnv->CanvasBind('<B2-Motion>' => sub {$drag_current = 1});
	$cnv->CanvasBind(
		'<ButtonRelease-2>' => sub {
			$drag_current || return();
			my @pan_stop = $cnv->eventLocation();
			my $scale = $cnv->pixelSize();
#            print "\tdouble: $isdouble\n";
#            print "\tdrag: $drag_current\n";
#            print "scale is $scale\n";
#            print "stopping pan at @pan_stop\n";
			my @diff = map({$pan_start[$_] - $pan_stop[$_]} 0,1);
#            my $panx = abs($diff[0])/$scale;
#            my $pany = abs($diff[1])/$scale;
#            print "pixels: ($panx,$pany)\n";
#            my $dopan = ( $panx > 10) | ( $pany > 10);
#            $dopan && print "panning by @diff\n";
#            $dopan && $cnv->panWorld(@diff);
			$cnv->panWorld(@diff);
			$drag_current = 0;
		});
	# zoom extents:
	$cnv->CanvasBind('<Double-Button-2>' => sub{$cnv->viewAll()});
	# zoom window:
	$mw->bind(
		'<z>' => sub {
			$stl->configure(-text=>"Pick window corners");
			windowzoom($cnv, $stl);
			});


} # end subroutine tkbindings definition
########################################################################

=head2 windowzoom

Creates temporary bindings to drawing a rubber-band box.

  windowzoom($cnv);

=cut
sub windowzoom {
	my $cnv = shift;
	my $stl = shift;
	$cnv->CanvasBind(
		'<ButtonPress-1>' => sub {
			$cnv->rubberBand(0);
		});
	$cnv->CanvasBind(
		'<B1-Motion>' => sub {
			$cnv->rubberBand(1);
		});
	$cnv->CanvasBind(
		'<ButtonRelease-1>' => sub {
			my @box = $cnv->rubberBand(2);
			#print "box is @box\n";
			$cnv->viewArea(@box);
			foreach my $item qw(
							<ButtonPress-1>
							<B1-Motion>
							<ButtonRelease-1>
							) {
				# print "item: $item\n";
				$cnv->CanvasBind($item => "");
			}
			$stl->configure(-text=>"");
		});
} # end subroutine windowzoom definition
########################################################################


=head2 tksetview

No longer used

  $drw->tksetview($cnv, %options);

=cut
sub tksetview {
	my $self = shift;
	my $cnv = shift;
	my %options = @_;
	my $width = $options{size}[0];
	my $height = $options{size}[1];
	my @ext = $self->OrthExtents($options{items});
	print "got extents: ", 
		join(" by ", map({join(" to ", @$_)} @ext)), "\n";
	my @cent = map({($_->[0] + $_->[1]) / 2} @ext);
	$options{center} && (@cent = @{$options{center}});
	print "center is @cent\n";
	my $scale = $options{scale};
	unless($scale) {
		$scale = $self->scalebox($options{size}, \@ext);
#        print "got scale: $scale\n";
	}
	$cnv->scale('all'=> 0,0 , $scale, $scale);
	my $bbox = $options{bbox};
	$_ *= $scale for @$bbox;
#    print "bbox now: @$bbox\n";
	$cnv->configure(-scrollregion=> $bbox);
#    my $xv = $ext[0][0] * $scale / $bbox->[2];
	my $xv = ($ext[0][0] * $scale - $bbox->[0]) / 
				($bbox->[2] - $bbox->[0]);
##    my $xv = ($width / 2 - $bbox->[0]) /
##                ($bbox->[2] - $bbox->[0]);

	print "xview: $xv\n";
	$cnv->xviewMoveto($xv);
	my (undef(), $yv) = tkpoint([0,$ext[1][0]]); 
	print "ypt: $yv\n";
	print "ext top: $ext[1][1] bottom: $ext[1][0]\n";
	print "bbox (t&b): $bbox->[1] $bbox->[3]\n";
	$yv = (-$ext[1][0] * $scale + $bbox->[3] - $height / 2) / 
				($bbox->[3] - $bbox->[1]);
	print "yview: $yv\n";
	$cnv->yviewMoveto($yv);
} # end subroutine tksetview definition
########################################################################

=head2 scalebox

Returns the scaling required to create a view which most closely
matches @ext to @size of canvas.

  $scale = $drw->scalebox(\@size, \@ext);

=cut
sub scalebox {
	my $self = shift;
	my ($size, $ext) = @_;
	my ($ew, $eh) = map({abs($_->[0] - $_->[1])} @$ext);
	my $dx = $size->[0] / $ew;
	my $dy = $size->[1] / $eh;
#    print "factors: $dx $dy\n";
	my $scale = [$dx => $dy] -> [$dy <= $dx];
	return($scale);
} # end subroutine scalebox definition
########################################################################

# FIXME: these currently do not store themselves
%dsp = (
	lines => sub {
		my ($self, $cnv, $addr) = @_;
		my $arrow = "none";
		$CAD::Drawing::IO::Tk::arrow && ($arrow = "last");
		my $obj = $self->getobj($addr);
		my $line = $cnv->createLine(
						map({tkpoint($_)} 
							@{$obj->{pts}},
							),
						'-fill'=> $aci2hex[$obj->{color}],
						'-arrow' => $arrow,
						);
#        print "line item: $line (ref: ", ref($line), ")\n";
	}, # end sub $dsp{lines}
	plines => sub {
		my ($self, $cnv, $addr) = @_;
		my $arrow = "none";
		$CAD::Drawing::IO::Tk::arrow && ($arrow = "last");
		my $obj = $self->getobj($addr);
		for(my $i = -1; $i < scalar(@{$obj->{pts}}) -1; $i++) {
			my $pline = $cnv->createLine(
						map({tkpoint($_)}
							$obj->{pts}[$i], $obj->{pts}[$i+1],
							),
						'-fill' => $aci2hex[$obj->{color}],
						'-arrow' => $arrow,
						);
#            print "pline item: $pline\n";
		}
	}, # end sub $dsp{plines}
	arcs => sub {
		my ($self, $cnv, $addr) = @_;
		my $obj = $self->getobj($addr);
#        print "keys: ", join(" ", keys(%$obj)), "\n";
		my $rad = $obj->{rad};
		my @pt = tkpoint($obj->{pt});
		# stupid graphics packages:
		my @rec = (
			map({$_ - $rad} @pt),
			map({$_ + $rad} @pt),
			);
		my @angs = @{$obj->{angs}};
		# stupid graphics packages:
		@angs = map({$_ * 180 / $pi} @angs);
		$angs[1] = $angs[1] - $angs[0];
		$angs[1] += 360;
		while($angs[1] > 360) {
			$angs[1] -= 360;
		}
		my $arc =  $cnv->createArc(
					@rec,
					'-start'  => $angs[0],
					'-extent' => $angs[1],
					'-outline' => $aci2hex[$obj->{color}],
					'-style' => "arc",
					);
	}, # end sub $dsp{arcs}
); # end %dsp coderef hash
########################################################################

=head2 tkpoint

Returns only the first and second element of an array reference as a
list.

  @xy_point = tkpoint(\@pt);

=cut
sub tkpoint {
	return($_[0]->[0], $_[0]->[1]);
} # end subroutine tkpoint definition
########################################################################

1;