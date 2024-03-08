#!/usr/bin/perl
use strict;
use warnings;
use Math::Trig qw(pi);
use Getopt::Long;
use Graphics::GnuplotIF;

my $width = 1600;
my $height = 1200;
my $S = 28;
my $n_points = 50;
my $small = 0.01;

{ ############################# main ######################################

  my $terminal = 'qt';
  my $persist = 0;
  my $enhanced = 0;
  my $line_width = 1;
  my $color = undef;
  my $pt_pair_color_spec = ' lt  rgb "#CC4444" ';

  my $alpha = 0; # to rotate whole parabola. 0 -> horizontal, opening to right.
  my $theta = 30;	     # half of angle between lines, in degrees
  my $isum = 10;
  my $max_lines = 300;

  GetOptions(
	     # control of binning, x and y ranges:
	     'width=f' => \$width,
	     'height=f' => \$height,
	     'theta=f' => \$theta,
	     'alpha=f' => \$alpha,
	     'npts|n_points=i' => \$n_points,
	     'isum=i' => \$isum,
	     'linewidth|line_width|lw=f' => \$line_width, # line thickness for histogram
	     'color=s' => \$color,
	     'terminal=s' => \$terminal, # x11, qt, at least, work.
	     'enhanced!' => \$enhanced,
	    );

  $theta *= pi/180;
  $alpha *= pi/180;
  my $origin = [$width/4, $height/2];

  my $V1 = [cos($theta + $alpha), sin($theta + $alpha)];
  my $V2 = [cos($theta - $alpha), -1.0*sin($theta - $alpha)];
  $S = int( sqrt($width*$width  +  $height*$height)/$n_points);

  my $gnuplotIF = Graphics::GnuplotIF->new(persist => $persist, style => 'linespoints');
  my $terminal_command = "set terminal $terminal noenhanced  linewidth  $line_width  size $width , $height";
  $gnuplotIF->gnuplot_cmd($terminal_command);
  $gnuplotIF->gnuplot_cmd("unset tic");
  $gnuplotIF->gnuplot_cmd("set clip two");
  $gnuplotIF->gnuplot_cmd("set size ratio -1");
  # $gnuplotIF->gnuplot_cmd("set grid");
  $gnuplotIF->gnuplot_cmd("plot [0:$width][0:$height] 0 t''");

  my $pts_string1 = points_string($origin, $V1, $S);
  my $pts_string2 = points_string($origin, $V2, $S);
  my $pts_string = $pts_string1 . $pts_string2; # each line has x and y coords
  open my $fh_write_pts, ">", "temp_pts_file";
  print $fh_write_pts "$pts_string";
  close $fh_write_pts;
  my $plot_points =  "'temp_pts_file' u 1:2 with points pt 6 t''";
  my $plot_lines = "'temp_lines_file' u 1:2:3:4 with vectors nohead t''";
  $gnuplotIF->gnuplot_cmd("plot [0:$width][0:$height] $plot_points");
  getc();

  unlink 'temp_lines_file'; # so when temp_lines_is first opened, below, it is empty.

  my $lines_drawn = 0;
  my $i1 = $isum - 1;
  my $i2 = $isum - $i1;
  while (1) {
    my $pt1 = sum2d($origin, $i1*$S, $V1);
    my $pt2 = sum2d($origin, $i2*$S, $V2);

    my $plot_pt_pair = "'-' u 1:2 with points pt 7 ps 0.6 $pt_pair_color_spec t''\n" . join(" ", @$pt1) . "\n" . join(" ", @$pt2) . "\n" . "e \n";
    my $command = "plot  [0:$width][0:$height] " . " $plot_lines , $plot_points , $plot_pt_pair ";
    $gnuplotIF->gnuplot_cmd($command);
    getc();

    # if (pt_is_in($width, $height, $pt1) > 0  or  pt_is_in($width, $height, $pt2) > 0) {
    if ($lines_drawn <= $max_lines  and  ! line_is_out($width, $height, $pt1, $pt2)) {
      open my $fh_write_lines, ">>", 'temp_lines_file';
      print $fh_write_lines join(" ", @{get_vector($pt1, $pt2)}), "\n";
      close $fh_write_lines;
      $gnuplotIF->gnuplot_cmd($command);
      $lines_drawn++;
      $i1--;
      $i2++;
    } else {
      last;
    }
    getc();
  }

  $i1 = $isum;
  $i2 = $isum - $i1;
  while (1) {
    my $pt1 = sum2d($origin, $i1*$S, $V1);
    my $pt2 = sum2d($origin, $i2*$S, $V2);

    my $plot_pt_pair = "'-' u 1:2 with points pt 7 ps 0.6 $pt_pair_color_spec t''\n" . join(" ", @$pt1) . "\n" . join(" ", @$pt2) . "\n" . "e \n";
    my $command = "plot  [0:$width][0:$height] " . " $plot_lines , $plot_points , $plot_pt_pair ";
    $gnuplotIF->gnuplot_cmd($command);
    getc();

    #if (pt_is_in($width, $height, $pt1) > 0  or  pt_is_in($width, $height, $pt2) > 0) {
    if ($lines_drawn <= $max_lines  and  ! line_is_out($width, $height, $pt1, $pt2)) {
      open my $fh_write_lines, ">>", 'temp_lines_file';
      print $fh_write_lines join(" ", @{get_vector($pt1, $pt2)}), "\n";
      close $fh_write_lines;
      $gnuplotIF->gnuplot_cmd($command);
      $lines_drawn++;
      $i1++;
      $i2--;
    } else {
      last;
    }
    getc();
  }

  while (1) {			# exit when 'q' or 'x' entered
    my $c = getc();
    exit() if($c eq 'q'  or $c eq 'x');
  }
} ######################################## end of main ###################################################

sub sum2d{			# return (as array ref)  $x1 + $a*$x2
  my $x1 = shift;
  my $a = shift;
  my $x2 = shift;
  return [$x1->[0] + $a*$x2->[0], $x1->[1] + $a*$x2->[1]];
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
  my $l = sqrt($d->[0]**2 + $d->[1]**2);
  $d->[0] /= $l;
  $d->[1] /= $l;
  return;
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
