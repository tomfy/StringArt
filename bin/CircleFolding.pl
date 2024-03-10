#!/usr/bin/perl
use strict;
use warnings;
use Math::Trig qw(pi);
use Getopt::Long;
use Graphics::GnuplotIF;


my $width = 1200;
my $height = 900;

my $small = 0.01;

{ ############################# main ######################################

  my $terminal = 'qt';
  my $persist = 0;
  my $enhanced = 0;
  my $point_size = 0.75;
  my $line_width = 1;
  my $points_color = ' "#007700" ';
  my $lines_color = ' "#0000AA" ';
  my $pt_pair_color = ' "#770000" ';

  my $radius = 300;
  my $ratio = 0.9;
  my $dtheta = 2; # spacing of pts on circle in degrees
  my $angular_offset = 70;

  GetOptions(
	     'width=f' => \$width,
	     'height=f' => \$height,
	     'dtheta=f' => \$dtheta, # angular increment (in degrees) of circle points
	     'radius=f' => \$radius, # radius of the circle in pixels
	     'ratio=f' => \$ratio, # $ratio < 1, focus inside circle -> ellipse; $ratio > 1, focus outside circle -> hyperbola

	     'pointsize|point_size=f' => \$point_size,
	     'linewidth|line_width|lw=f' => \$line_width, # line thickness
	     'pts_color=s' => \$points_color,
	     'lines_color=s' => \$lines_color,
	     'pt_pair_color=s' => \$pt_pair_color,
	     'terminal=s' => \$terminal, # x11, qt, at least, work.
	     'enhanced!' => \$enhanced,
	    );

  $dtheta *= pi/180;
  $angular_offset *= pi/180;
  my $diagonal = sqrt($width**2 + $height**2);
  my $origin = [($width - $ratio*$radius)/2, $height/2];

  my $gnuplotIF = Graphics::GnuplotIF->new(persist => $persist, style => 'linespoints');
  my $terminal_command = "set terminal $terminal noenhanced  linewidth  $line_width  size $width , $height";
  $gnuplotIF->gnuplot_cmd($terminal_command);
  $gnuplotIF->gnuplot_cmd("unset tic");
  $gnuplotIF->gnuplot_cmd("set clip two");
  $gnuplotIF->gnuplot_cmd("set size ratio -1", "set pointsize $point_size");

  my $focus = sum2d([0, 0], $radius*$ratio, [1, 0]);
  my $Focus = sum2d($origin, 1.0, $focus);

  my $plot_str = '';
  for (my $theta = 0.5*$dtheta; $theta < 2*pi; $theta += $dtheta) {
    my $pt_on_circle = [$radius*cos($theta + $angular_offset), $radius*sin($theta + $angular_offset)];
    my $Pt_on_circle = sum2d($origin, 1.0, $pt_on_circle);
    my $midpoint = linearcomb2d(0.5, $focus, 0.5, $pt_on_circle);
    my $Midpoint = sum2d($origin, 1.0, $midpoint);

    my $v = sum2d($pt_on_circle, -1.0, $focus);
    $v = norm($v); # normalized separation between focus and pt on circle

    my $v_perp = [$v->[1], -1.0*$v->[0]]; # rotated 90 degrees
    my $x = sum2d($midpoint, -1*$diagonal, $v_perp);
    my $dx = sum2d([0, 0], 2*$diagonal, $v_perp);
    my $X = sum2d($origin, 1.0, $x);
    $plot_str .= join(" ", @$Focus). "    " . join(" ", @$Pt_on_circle) . "    ". join(" ", @$Midpoint). "    ". join(" ", @$X) . " " . join(" ", @$dx) . "\n";
    my $data_block_command = '$datablock << EOD' . "\n" . $plot_str . "EOD\n";
    $gnuplotIF->gnuplot_cmd($data_block_command);

    my $pcommand = "plot [0:$width][0:$height] ";
    $pcommand .= '$datablock ' . " using 1:2 with points pt 7 t'', ";
    $pcommand .= '$datablock ' . " using 3:4 pt 7 t'', ";
  #  $pcommand .= '$datablock ' . " using 5:6 pt 7 t'',";  # to show midpoint between circle and focus
    $pcommand .= '$datablock ' . " using 7:8:9:10 with vectors nohead t''";
    $gnuplotIF->gnuplot_cmd($pcommand);
    getc();
  }

  while(1){
    my $c = lc getc();
    exit() if($c eq 'x'  or  $c eq 'q');
  }
} ######################################## end of main ###################################################

sub sum2d{			# return (as array ref)  $x1 + $a*$x2
  my $x1 = shift;
  my $a = shift;
  my $x2 = shift;
  return [$x1->[0] + $a*$x2->[0], $x1->[1] + $a*$x2->[1]];
}

sub linearcomb2d{
  my $a1 = shift;
  my $x1 = shift;
  my $a2 = shift;
  my $x2 = shift;
  return [$a1*$x1->[0] + $a2*$x2->[0], $a1*$x1->[1] + $a2*$x2->[1]];
}

sub midpt2d{
  my $p1 = shift;
  my $p2 = shift;
  return [0.5*($p1->[0] + $p2->[0]), 0.5*($p1->[1] + $p2->[1])];
}

sub pt_is_in{ # 0 if both coords are outside, 2 if both inside, 1 if exactly 1 inside.
  my $w = shift;		# width
  my $h = shift;
  my $pt = shift;
  my $in_count = 0;
  my ($x, $y) = @$pt;
  $in_count++ if(0 < $x and $x < $w);
  $in_count++ if(0 < $y  and $y < $height);
  return $in_count;
}

sub line_is_out{
  my $w = shift;
  my $h = shift;
  my ($x1, $y1) = @{ ( shift ) };
  my ($x2, $y2) = @{ ( shift ) };
  if ($x1 < 0) {
    return 1 if($x2 < 0);
  } elsif ($x1 > $width) {
    return 1 if($x2 > $width);
  }
  if ($y1 < 0) {
    return 1 if($y2 < 0);
  } elsif ($y1 > $height) {
    return 1 if($y2 > $height);
  }
  return 0;
}

sub points_string{
  my $origin = shift;
  my $V = shift;
  my $S = shift;
  my $i_init = 1;
  my $string = '';
  my $i = $i_init;
  my $pt;
  while (1) {
    my $in_count = 0;
    $pt = sum2d($origin, $i*$S, $V);
    $in_count = pt_is_in($width, $height, $pt);
    if ($in_count == 2) {
      $string .= join(" ", @$pt) . "\n";
    } else {
      last;
    }
    $i++;
  }
  $i = 0;
  while (1) {
    my $in_count = 0;
    $pt = sum2d($origin, $i*$S, $V);
    $in_count = pt_is_in($width, $height, $pt);
    if ($in_count == 2) {
      $string .= join(" ", @$pt) . "\n";
    } else {
      last;
    }
    $i--;
  }
  return $string;
}

sub get_vector{
  my $pt1 = shift;
  my $pt2 = shift;
  my ($dx, $dy) = @{sum2d($pt2, -1, $pt1)}; # pt2 - pt1
  if (abs($dx) > $small  or  abs($dy) > $small) {
    if (abs($dx) >= abs($dy)) {
      my $AL = -1.0*$pt1->[0]/$dx;
      my $AR = ($width-$pt1->[0])/$dx;
      my $xL = 0;
      my $xR = $width;
      my $yL = ($pt1->[1] + $AL*$dy);
      my $yR = ($pt1->[1] + $AR*$dy);
      return  [$xL, $yL, $xR-$xL, $yR-$yL];
    } else {			# dy > dx
      my $AB = -1.0*$pt1->[1]/$dy;
      my $AT = ($height-$pt1->[1])/$dy;
      my $xB = ($pt1->[0] + $AB*$dx);
      my $xT = ($pt1->[0] + $AT*$dx);
      my $yB = 0;
      my $yT = $height;
      return [$xB, $yB, $xT-$xB, $yT-$yB];
    }
  }
}

################################################################################

sub norm{
  my $d = shift;
  my $l = sqrt($d->[0]**2 + $d->[1]**2);
  $d->[0] /= $l;
  $d->[1] /= $l;
  return $d;
}

sub lines_command{
  my $w = shift;
  my $h = shift;
  my $endpoints = shift;

  my $command = ''; # "plot [0:$w][0:$h] '-' using 1:2:3:4 with vectors nohead t'' \n";
  for my $pt_pair (@$endpoints) {
    my $dx =  $pt_pair->[2] - $pt_pair->[0];
    my $dy =  $pt_pair->[3] - $pt_pair->[1];
    $command .=			#join(" ", @$pt_pair) . "\n";
      $pt_pair->[0] . " " . $pt_pair->[1] . "  $dx  $dy \n";
  }
  $command .= "e\n";
  return $command;
}
