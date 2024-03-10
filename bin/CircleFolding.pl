#!/usr/bin/perl
use strict;
use warnings;
use Math::Trig qw(pi);
use Getopt::Long;
use Graphics::GnuplotIF;


my $width = 1200;
my $height = 900;

#my $S = 28;
#my $n_points = 50;
my $small = 0.01;

{ ############################# main ######################################

  my $terminal = 'qt';
  my $persist = 0;
  my $enhanced = 0;
  my $point_size = 0.5;
  my $line_width = 1;
  my $points_color = ' "#007700" ';
  my $lines_color = ' "#0000AA" ';
  my $pt_pair_color = ' "#770000" ';

  my $radius = 200;
  my $ratio = 0.9;
 # my $alpha = 0; # to rotate whole parabola. 0 -> horizontal, opening to right.
  #my $theta = 0; # half of angle between lines, in degrees
  my $dtheta = 2;		# degrees
#  my $isum = 10;
#  my $max_lines = 300;

  GetOptions(
	     # control of binning, x and y ranges:
	     'width=f' => \$width,
	     'height=f' => \$height,
	     'dtheta=f' => \$dtheta,
	     'radius=f' => \$radius,
	     'ratio=f' => \$ratio,
	    # 'npts|n_points=i' => \$n_points,
	     # 'isum=i' => \$isum,
	     'pointsize|point_size=f' => \$point_size,
	     'linewidth|line_width|lw=f' => \$line_width, # line thickness for histogram
	     'pts_color=s' => \$points_color,
	     'lines_color=s' => \$lines_color,
	     'pt_pair_color=s' => \$pt_pair_color,
	     'terminal=s' => \$terminal, # x11, qt, at least, work.
	     'enhanced!' => \$enhanced,
	    );

  $dtheta *= pi/180;
 # $alpha *= pi/180;
  my $origin = [($width - $radius)/2, $height/2];

  # my $V1 = [cos($theta + $alpha), sin($theta + $alpha)];
  # my $V2 = [cos($theta - $alpha), -1.0*sin($theta - $alpha)];
  # $S = int( sqrt($width*$width  +  $height*$height)/$n_points);

  my $gnuplotIF = Graphics::GnuplotIF->new(persist => $persist, style => 'linespoints');
  my $terminal_command = "set terminal $terminal noenhanced  linewidth  $line_width  size $width , $height";
  $gnuplotIF->gnuplot_cmd($terminal_command);
  $gnuplotIF->gnuplot_cmd("unset tic");
  $gnuplotIF->gnuplot_cmd("set clip two");
  $gnuplotIF->gnuplot_cmd("set size ratio -1", "set pointsize $point_size");
  # $gnuplotIF->gnuplot_cmd("set grid");
  #$gnuplotIF->gnuplot_cmd("plot [0:$width][0:$height] 0 t''");

  # my $pts_string1 = points_string($origin, $V1, $S);
  # my $pts_string2 = points_string($origin, $V2, $S);
  # my $pts_string = $pts_string1 . $pts_string2; # each line has x and y coords
  # open my $fh_write_pts, ">", "temp_pts_file";
  # print $fh_write_pts "$pts_string";
  # close $fh_write_pts;
  # my $plot_points =  "'temp_pts_file' u 1:2 with points pt 6  lt rgb $points_color t'' ";
  # # $plot_points .= " lt rgb $points_color ";
  # print STDERR $plot_points, "\n";
  my $plot_lines = "'temp_lines_file' u 1:2:3:4 with vectors nohead  lt rgb $lines_color t'' ";
  #$gnuplotIF->gnuplot_cmd("plot [0:$width][0:$height] $plot_points");
  #my $c = lc getc();
  #exit() if($c eq 'q'  or $c eq 'x');

  unlink 'temp_lines_file'; # so when temp_lines_is first opened, below, it is empty.

  # my $radius = 100;
  my $fr = $radius*$ratio;
  my $focus = sum2d([0, 0], $fr, [1, 0]);
  my $Focus = sum2d($origin, 1.0, $focus);

  my $plot_pts_str = '';
  my $plot_lines_str = '';
  my $plot_str = '';
  for (my $theta = 0.5*$dtheta; $theta < 2*pi; $theta += $dtheta) {
    my $pt_on_circle = [$radius*cos($theta), $radius*sin($theta)];
    my $Poc = sum2d($origin, 1.0, $pt_on_circle);
    my $midpoint = linearcomb2d(0.5, $focus, 0.5, $pt_on_circle);
    my $Midpoint = sum2d($origin, 1.0, $midpoint);

    my $mp = sum2d($origin, 1.0, $midpoint);
    my $v = sum2d($pt_on_circle, -1.0, $focus);
    $v = norm($v);

    my $vperp = [$v->[1], -1.0*$v->[0]]; # rotated 90 degrees
    print STDERR "vperp: ", join(" ", @$vperp), "\n";
    my $x = sum2d($midpoint, -1000, $vperp);
    my $dx = sum2d([0, 0], 2000, $vperp);
    print STDERR "dx: ", join(" ", @$dx), " \n";
    # getc();
    my $X = sum2d($origin, 1.0, $x);
    $plot_lines_str .= join(" ", @$X) . "  " . join(" ", @$dx) . "\n";
    $plot_str .= join(" ", @$Focus). "    ". join(" ", @$Poc). "    ". join(" ", @$Midpoint). "    ". join(" ", @$X) . " " . join(" ", @$dx) . "\n";
    print STDERR "XXX: [$plot_str]\n";
    my $data_block_command = '$datablock << EOD' . "\n" . $plot_str . "EOD\n";
    $gnuplotIF->gnuplot_cmd($data_block_command);

    #print STDERR $theta*180/pi, "  ", join(" ", @$focus), "  ", join(" ", @$pt_on_circle), "  ", join(" ", @$midpoint), "  ", join(" ", @$Poc), "\n";
    $plot_pts_str .= join(" ", @$X) . "  " . join(" ", @{ sum2d($X, 1.0, $dx)}) . "\n"; #$mp->[0] . " " . $mp->[1] . " ", "\n";
    #print STDERR "plot_lines_str: $plot_lines_str \n";
    my $pls_command = "plot [0:$width][0:$height] '-' using 1:2:3:4 with vectors nohead \n  $plot_lines_str e";
    #print STDERR "[$pls_command] \n";
    my $pcommand = "plot [0:$width][0:$height] ";
    $pcommand .= '$datablock ' . " using 1:2 with points pt 7 t'', ";
    $pcommand .= '$datablock ' . " using 3:4 pt 7 t'', ";
  #  $pcommand .= '$datablock ' . " using 5:6 pt 7 t'',";
    $pcommand .= '$datablock ' . " using 7:8:9:10 with vectors nohead t''";
    #$pcommand .= "\n";
    #$pcommand .= $plot_str . "e\n";
    print STDERR "[[ $pcommand ]]\n";
    $gnuplotIF->gnuplot_cmd($pcommand);
    getc();
  }

  # print STDERR "BBB: $plot_pts_str \n";

  # $gnuplotIF->gnuplot_cmd("plot [0:$width][0:$height] '-' using 1:2:3:4 with vectors nohead  $plot_lines_str \n e");

  # getc();
  # $gnuplotIF->gnuplot_cmd("plot [0:$width][0:$height] '-' using 1:2 with points pt 7, '' using 3:4 with points $plot_pts_str e");

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
      my $xL = 0;		# ($pt1->[0] + $AL*$dx); = 0;
      my $xR = $width;		# ($pt1->[0] + $AR*$dx); = $width;
      my $yL = ($pt1->[1] + $AL*$dy);
      my $yR = ($pt1->[1] + $AR*$dy);
      return  [$xL, $yL, $xR-$xL, $yR-$yL];
    } else {			# dy > dx
      my $AB = -1.0*$pt1->[1]/$dy;
      my $AT = ($height-$pt1->[1])/$dy;
      my $xB = ($pt1->[0] + $AB*$dx);
      my $xT = ($pt1->[0] + $AT*$dx);
      my $yB = 0;		# ($pt1->[1] + $AL*$dy);
      my $yT = $height;		# ($pt1->[1] + $AR*$dy);
      return [$xB, $yB, $xT-$xB, $yT-$yB];
    }
  }
}

################################################################################

sub norm{
  my $d = shift;
  print STDERR "In norm d: ", join(" ", @$d), "\n";
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
