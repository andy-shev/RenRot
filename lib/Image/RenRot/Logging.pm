package Image::RenRot::Logging;

#
# vim: ts=2 sw=2 et :
#

########################################################################################
###                                 MESSAGING                                        ###
########################################################################################

use strict;
use warnings;
require 5.006;
require Exporter;
use Term::ANSIColor;

$Term::ANSIColor::AUTORESET = 1;
$Term::ANSIColor::EACHLINE = "\n";
$ENV{ANSI_COLORS_DISABLED} = 1;

use Image::RenRot::Util;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(procmsg infomsg warnmsg errmsg fatalmsg dbgmsg ldbg3 ldbg3opts);

my %options = (
  Quiet     => 0, # suppressing messages
  Verbose   => 0, # verbosity of output
  UseColor  => 0, # whether use color output
);

#
# Colors hash
#
my %colors = (
  debug   => {value => 'green'},
  error   => {value => 'magenta'},
  fatal   => {value => 'red'},
  info    => {value => 'bold'},
  process => {value => 'white'},
  warning => {value => 'cyan'},
);

sub set {
  my $self = shift;

  while (@_) {
    my $option = shift;
    my $value = shift;

    if ($option eq 'Color') {
      map { $colors{$_} = $value->{$_} } keys %$value;
    } else {
      $options{$option} = $value;
    }
  }

  # Setup color output properly
  if ($options{UseColor}) {
    delete $ENV{ANSI_COLORS_DISABLED};
  } else {
    $ENV{ANSI_COLORS_DISABLED} = 1;
  }
}

# Prints colored message to STDERR or STDOUT
sub do_print {
  my $facility = shift;

  if ($options{UseColor} and defined $colors{$facility}) {
    # Put process and info messages to StdOut, otherwise to StdErr
    if ($facility eq "process" or $facility eq "info") {
      print STDOUT colored[$colors{$facility}{value}], @_;
    } else {
      print STDERR colored[$colors{$facility}{value}], @_;
    }
  } else {
    # fallback to normal print
    if ($facility eq "process" or $facility eq "info") {
      print STDOUT @_;
    } else {
      print STDERR @_;
    }
  }
}

# general processing message
sub procmsg {
  do_print('process', @_) if ($options{Quiet} == 0);
}

# information message
sub infomsg {
  do_print('info', @_);
}

# warning message
sub warnmsg {
  do_print('warning', "Warning: ", @_);
}

# error message
sub errmsg {
  do_print('error', "ERROR: ", @_);
}

# fatal message
sub fatalmsg {
  do_print('fatal', "FATAL: ", @_);
}

# debug message
sub dbgmsg {
  my $level = shift;
  if ($options{Verbose} >= $level) {
    my $funcname = (caller(1))[3];  # caller() described in Perl Cookbook 10.4
    do_print('debug', "DEBUG[$level]: ", defined $funcname ? $funcname : 'main', "(): ", @_);
  }
}

########################################################################################
# Usage      : ldbg3($msg, ...)
# Purpose    : prints debug message on level 3 with EOL
# Returns    : nothing
# Parameters : text message without end of line
# Throws     : no exceptions
# Comments   : useful to print command line or configuration option parameters
# See Also   : dbgmsg()
sub ldbg3 {
  if ($options{Verbose} >= 3) {
    my $funcname = (caller(1))[3];  # caller() described in Perl Cookbook 10.4
    do_print('debug', "DEBUG[3]: ", defined $funcname ? $funcname : 'main', "(): ", @_, "\n");
  }
}

########################################################################################
#
# ldbg3opts() prints option values from given hash
#
sub ldbg3opts {
  my $hash = shift;
  my $option = shift;

  while (my ($k, $v) = each %{$hash->{$option}}) {
    next if (not defined $v->{value});

    my ($value, $default);
    if (not defined $v->{type} or $v->{type} ne "!") {
      $value = $v->{value};
      $default = $v->{default};
    } else {
      $value = bool2str($v->{value});
      $default = bool2str($v->{default});
    }

    if (not defined $default) {
      ldbg3("--> '$option $k': $value");
    } else {
      ldbg3("--> '$option $k': $value (default: $default)");
    }
  }
}

########################################################################################
1;  # end
