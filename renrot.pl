#! PERL_BINARY -w
#
# $Id: renrot 299 2007-09-01 08:50:11Z zeus $
#

use strict;
use warnings;
use diagnostics;
require 5.006;
use Time::localtime;
use Time::Local;
use Image::ExifTool;
use Getopt::Long;

use Term::ANSIColor;

$Term::ANSIColor::AUTORESET = 1;
$Term::ANSIColor::EACHLINE = "\n";

our $VERSION = "0.25.20070902";		# the version of this script
my $maxVerbosity = 4;			# our max verbosity level (internal)
my $homeURL = 'https://puszcza.gnu.org.ua/projects/renrot/';	# homepage of the project

########################################################################################
#
# The global definition for a new XMP namespace. The
# %Image::ExifTool::UserDefined::RenRot defines XMP-RenRot tags which could be
# added to mark the file as processed with RenRot.
#
if (defined %Image::ExifTool::UserDefined::RenRot) {
	fatalmsg ("Won't redefine Image::ExifTool::UserDefined::RenRot.\n"), die;
}

%Image::ExifTool::UserDefined::RenRot = (
	GROUPS => { 0 => 'XMP', 1 => 'RenRot', 2 => 'Image' },
	NAMESPACE => [ 'RenRot' => $homeURL ],
	WRITABLE => 'string',
	RenRotFileNameOriginal => { },
	RenRotProcessingTimestamp => { },
	RenRotVersion => { },
	RenRotURL => { },
);

# The %Image::ExifTool::UserDefined hash defines new tags to be added to
# existing tables.
%Image::ExifTool::UserDefined = (
	# new XMP namespaces must be added to the Main XMP table
	'Image::ExifTool::XMP::Main' => {
		RenRot => {
			SubDirectory => {
				TagTable => 'Image::ExifTool::UserDefined::RenRot',
			},
		},
	},
);

########################################################################################
#
# Parsed configuration file in hash
#
my %cfgOpts = (
			'aggregation delta' => 900,
			'aggregation directory' => 'Images',
			'aggregation mode' => 'none',
			'aggregation template' => '%Y%m%d',
			'aggregation virtual' => 0,
			'aggregation virtual directory' => 'Images.Links.Directory',
			'keywordize' => 0,
			'keywords file' => '.keywords',
			'keywords replace' => 0,
			'mtime' => 1,
			'name template' => '%Y%m%d%H%M%S',
			'trim' => 1,
			'use color' => 0,
			'use ipc' => 0,
			'contact sheet' => 0,
			'contact sheet tile' => '7x5',
			'contact sheet title' => 'Default Contact Sheet Title',
			'contact sheet file' => 'cs',
			'contact sheet dir' => 'CS.TMP',
			'contact sheet background' => 'FFF',
			'contact sheet bordercolor' => 'DDD',
			'contact sheet mattecolor' => 'CCC',
			'contact sheet fill' => '000',
			'contact sheet font' => 'Helvetica',
			'contact sheet label' => '%t',
			'contact sheet frame' => '3',
			'contact sheet pointsize' => '11',
			'contact sheet shadow' => 1,
	      );

########################################################################################
#
# Command line options
#
my $aggrDelta;		# aggregation time delta in seconds (file with delta > $aggrDelta is placed in new DIR)
my $aggrDir;		# counterless directory name for "delta" type aggregation
my $aggrMode;		# define aggregation mode, possible values are: none, delta or template
my $aggrTemplate;	# template for the files aggregation taken from CLI
my $aggrVirtual;	# flag to do links instead real file moving while aggregation
my $aggrVirtDir;	# directory name for virtual aggregation
my $backup = 1;		# make or not a backup of the original files
my $comfile;		# file with commentary
my $configFile;		# configuration file
my $contactSheet;       # contact sheet generation
my $contactSheetTile;	# tile in the montage
my $contactSheetTitle;	# title for the montage
my $contactSheetFile;	# file name for the montage
my $contactSheetDir;	# tmp directory for the montage operations
my $contactSheetThm = 0;# is $extToProcess files are the thumbnails?
my $contactSheetBg;	# background, look ImageMagick documentation for montage options
my $contactSheetBd;	# bordercolor, look ImageMagick documentation for montage options
my $contactSheetMt;	# mattecolor, look ImageMagick documentation for montage options
my $contactSheetFn;	# font, look ImageMagick documentation for montage options
my $contactSheetLb;	# label, look ImageMagick documentation for montage options
my $contactSheetFl;	# fill, look ImageMagick documentation for montage options
my $contactSheetFr;	# frame, look ImageMagick documentation for montage options
my $contactSheetPntSz;	# pointsize, look ImageMagick documentation for montage options
my $contactSheetShadow;	# shadow, look ImageMagick documentation for montage options
my $countFF = 1;	# use fixed field for counter
my $countStart = 1;	# Start value for counter
my $countStep = 1;	# Step for counter
my $dryRun = 0;		# show what would have been happened
my @excludeList;	# files that will be excluded from list
my $extToProcess = '';	# the extension of files to work with
my $keywordize;		# keywordize or not
my $keywordsReplace;	# whether to add keywords to the existent ones or replace them
my $keywordsFile;	# file with keyword set
my $mtime;		# mtime taken from CLI
my $nameTemplate;	# template for the filename taken from CLI
my $noRename = 0;	# no rename needed, default is to rename to the YYYYmmddHHMMSS.ext
my $noRotation = 0;	# no rotation needed, default is to rotate
my $noTags = 0;		# no tags writing needed
my $orientTag = 0;	# rotate by changing Orientation tag (no real rotation)
my $quiet = 0;		# suppressing messages
my $rotateAngle;	# define the angle to rotate on 90, 180 or 270
my $rotateThumbnail; 	# define the angle to rotate on 90, 180 or 270
my $subFileSet = '';	# subset of files to process, given in file rather than in commandline
my %tagsFromCli;	# tags are got from CLI
my $trim;		# jpegtran -trim
my $useColor;		# colorized output
my $useIPC;		# rotate thumbnail via pipe
my $userComment;	# text to put into UserComment tag
my $verbose = 0;	# verbosity of output
my $workDir = './';	# we'll work ONLY in current directory
my $isThereIM = 0;	# is there Image::Magick package?

########################################################################################
#
# Tags hash for injecting to EXIF when renaming
#
my %tags = (
		'RenRotProcessingTimestamp' => {
			value => timeNow(),
			group => 'RenRot',
		},
		'RenrotVersion' => {
			value => $VERSION,
			group => 'RenRot',
		},
		'RenRotURL' => {
			value => $homeURL,
			group => 'RenRot',
		},
	   );		# define tags for filling

########################################################################################
#
# Global variables (internal)
#
my @rotparms = (
		'',
		'-flip horizontal',
		'-rotate 180',
		'-flip vertical',
		'-transpose',
		'-rotate 90',
		'-transverse',
		'-rotate 270',
	       );	# array of options to jpegtran to rotate the file

my @angles = (
		'',
		'fh',
		'180cw',
		'fv',
		'tp',
		'90cw',
		'tv',
		'270cw',
	     );		# the array of suffixes to add to the newfilename after rotating

my %rotangles = (
			'90' => '-rotate 90',
			'180' => '-rotate 180',
			'270' => '-rotate 270'
		);	# array of options to rotate file "by hands"

my %rotorient = (
		        1 => 0,
			6 => 90,
		        3 => 180,
			8 => 270,
		);

my %rotorientrev = reverse %rotorient;

my %incFiles;		# hash of included files while parsing configuration file

my @multOpts = (
		'color',
		'include',
		'tag',
		'tagfile',
	       );

my @files;		# array of the sorted filenames to process
my %filenameshash;	# hash for old file names

########################################################################################
#
# Colors hash
#
my %colors = (
	debug => {value => 'green'},
	error => {value => 'magenta'},
	fatal => {value => 'red'},
	info => {value => 'bold'},
	process => {value => 'white'},
	warning => {value => 'cyan'},
);

# Prints colored message to STDERR
sub printColored {
	my $facility = shift;

	if ($cfgOpts{'use color'} != 0) {
		if (defined $facility and defined $colors{$facility}) {
			print STDERR colored [$colors{$facility}{value}], @_;
			return;
		}
	}

	print STDERR @_;	# fallback to normal print
}

# processing message
sub procmsg {
	return if ($quiet != 0);

	if ($cfgOpts{'use color'} != 0) {
		if (defined $colors{'process'}) {
			print colored [$colors{'process'}{value}], @_;
			return;
		}
	}

	print @_;		# fallback to normal print
}

# information message
sub infomsg {
	printColored('info', @_);
}

# warning message
sub warnmsg {
	printColored('warning', "Warning: ", @_);
}

# error message
sub errmsg {
	printColored('error', "ERROR: ", @_);
}

# fatal message
sub fatalmsg {
	printColored('fatal', "FATAL: ", @_);
}

# debug message
sub dbgmsg {
	my $level = shift;
	if ($verbose >= $level) {
		printColored('debug', "DEBUG[$level]: ", @_);
	}
}

########################################################################################
#
# boolConv() converts boolean value to human readable string
#
sub boolConv {
	my $var = shift;
	if ($var == 0) {
		return "No";
	} else {
		return "Yes";
	}
}

########################################################################################
#
# boolConverter() converts given string to a boolean value
#
sub boolConverter {
	my $value = shift;
	if ($value =~ m/^(0|No|False|Off)$/i) {
		return 0;
	} elsif ($value =~ m/^(1|Yes|True|On)$/i) {
		return 1;
	}
	return $value;
}

########################################################################################
#
# isTherePackage() checks availability of some package renrot could be dependent of
#
sub isTherePackage {
	my $pkg = shift;
	return undef unless eval "require $pkg";
}

########################################################################################
#
# getOptions() parses command line arguments
#
sub getOptions {
	my $showVersion = 0;	# need version
	my $showHelp = 0;	# need help
	my @tmpTags;
	my $getOptions = GetOptions (
					"aggr-delta=i" => \$aggrDelta,
					"aggr-directory=s" => \$aggrDir,
					"aggr-mode=s" => \$aggrMode,
					"aggr-template|a=s" => \$aggrTemplate,
					"aggr-virtual!" => \$aggrVirtual,
					"aggr-virtual-directory=s" => \$aggrVirtDir,
					"backup!" => \$backup,
					"comment-file=s" => \$comfile,
					"config-file|c=s" => \$configFile,
					"contact-sheet-tile=s" => \$contactSheetTile,
					"contact-sheet" => \$contactSheet,
					"contact-sheet-title=s" => \$contactSheetTitle,
					"contact-sheet-file=s" => \$contactSheetFile,
					"contact-sheet-dir=s" => \$contactSheetDir,
					"contact-sheet-thm" => \$contactSheetThm,
					"contact-sheet-bg=s" => \$contactSheetBg,
					"contact-sheet-bd=s" => \$contactSheetBd,
					"contact-sheet-mt=s" => \$contactSheetMt,
					"contact-sheet-fl=s" => \$contactSheetFl,
					"contact-sheet-fn=s" => \$contactSheetFn,
					"contact-sheet-lb=s" => \$contactSheetLb,
					"contact-sheet-fr=s" => \$contactSheetFr,
					"contact-sheet-pntsz=i" => \$contactSheetPntSz,
					"contact-sheet-shadow" => \$contactSheetShadow,
					"counter-fixed-field!" => \$countFF,
					"counter-start=i" => \$countStart,
					"counter-step=i" => \$countStep,
					"dry-run" => \$dryRun,
					"exclude=s" => \@excludeList,
					"extension|e=s" => \$extToProcess,
					"help|?"   => \$showHelp,
					"keywordize!" => \$keywordize,
					"keywords-file|k=s" => \$keywordsFile,
					"keywords-replace!" => \$keywordsReplace,
					"mtime!" => \$mtime,
					"name-template|n=s" => \$nameTemplate,
					"no-rename|norename" => \$noRename,
					"no-rotate|norotate" => \$noRotation,
					"no-tags|notags" => \$noTags,
					"only-orientation" => \$orientTag,
					"quiet|q" => \$quiet,
					"rotate-angle|r=i" => \$rotateAngle,
					"rotate-thumb=i" => \$rotateThumbnail,
					"sub-fileset=s" => \$subFileSet,
					"tag|t=s" => \@tmpTags,
					"trim!" => \$trim,
					"use-color!" => \$useColor,
					"use-ipc!" => \$useIPC,
					"user-comment=s" => \$userComment,
					"v+" => \$verbose,
					"version" => \$showVersion,
					"work-directory|d=s" => \$workDir,
				    );

	my $fileCount = scalar(@ARGV);

	dbgmsg (3, "   --aggr-delta: $aggrDelta\n") if (defined $aggrDelta);
	dbgmsg (3, "   --aggr-directory: $aggrDir\n") if (defined $aggrDir);
	dbgmsg (3, "   --aggr-mode: $aggrMode\n") if (defined $aggrMode);
	dbgmsg (3, "   --aggr-template: $aggrTemplate\n") if (defined $aggrTemplate);
	dbgmsg (3, "   --aggr-virtual: ", boolConv($aggrVirtual), "\n") if (defined $aggrVirtual);
	dbgmsg (3, "   --aggr-virtual-directory: $aggrVirtDir\n") if (defined $aggrVirtDir);
	dbgmsg (3, "   --backup: ", boolConv($backup), "\n");
	dbgmsg (3, "   --comment-file: $comfile\n") if (defined $comfile);
	dbgmsg (3, "   --config-file: $configFile\n") if (defined $configFile);
	dbgmsg (3, "   --contact-sheet: ", boolConv($contactSheet),"\n") if (defined $contactSheet);
	dbgmsg (3, "   --contact-sheet-tile: $contactSheetTile\n") if (defined $contactSheetTile);
	dbgmsg (3, "   --contact-sheet-title: $contactSheetTitle\n") if (defined $contactSheetTitle);
	dbgmsg (3, "   --contact-sheet-file: $contactSheetFile\n") if (defined $contactSheetFile);
	dbgmsg (3, "   --contact-sheet-dir: $contactSheetDir\n") if (defined $contactSheetDir);
	dbgmsg (3, "   --contact-sheet-thm: ", boolConv($contactSheetThm),"\n");
	dbgmsg (3, "   --contact-sheet-bg: $contactSheetBg\n") if (defined $contactSheetBg);
	dbgmsg (3, "   --contact-sheet-bd: $contactSheetBd\n") if (defined $contactSheetBd);
	dbgmsg (3, "   --contact-sheet-mt: $contactSheetMt\n") if (defined $contactSheetMt);
	dbgmsg (3, "   --contact-sheet-fn: $contactSheetFn\n") if (defined $contactSheetFn);
	dbgmsg (3, "   --contact-sheet-lb: $contactSheetLb\n") if (defined $contactSheetLb);
	dbgmsg (3, "   --contact-sheet-fr: $contactSheetFr\n") if (defined $contactSheetFr);
	dbgmsg (3, "   --counter-start: $countStart",
		   "   --counter-step: $countStep",
		   "   --counter-fixed-field: ", boolConv($countFF), "\n");
	dbgmsg (3, "   --dry-run: ", boolConv($dryRun), "\n") if (defined $dryRun);
	dbgmsg (3, "   --exclude:\n", join("\n", @excludeList), "\n") if (scalar(@excludeList) > 0);
	dbgmsg (3, "   --extension: $extToProcess\n");
	dbgmsg (3, "   --keywordize: ", boolConv($keywordize), "\n") if (defined $keywordize);
	dbgmsg (3, "   --keywords-replace: ", boolConv($keywordsReplace), "\n") if (defined $keywordsReplace);
	dbgmsg (3, "   --keywords-file: $keywordsFile\n") if (defined $keywordsFile);
	dbgmsg (3, "   --mtime: ", boolConv($mtime), "\n") if (defined $mtime);
	dbgmsg (3, "   --name-template: $nameTemplate\n") if (defined $nameTemplate);
	dbgmsg (3, "   --no-rename: ", boolConv($noRename),
		   "   --no-rotate: ", boolConv($noRotation),
		   "   --no-tags: ", boolConv($noTags), "\n");
	dbgmsg (3, "   --only-orientation: ", boolConv($orientTag), "\n");
	dbgmsg (3, "   --rotate-angle: $rotateAngle\n") if (defined $rotateAngle);
	dbgmsg (3, "   --rotate-thumb: $rotateThumbnail\n") if (defined $rotateThumbnail);
	dbgmsg (3, "   --sub-fileset: $subFileSet\n") if ($subFileSet ne "");
	dbgmsg (3, "   --tag:\n", join("\n", @tmpTags), "\n") if (scalar(@tmpTags) > 0);
	dbgmsg (3, "   --trim: ", boolConv($trim), "\n") if (defined $trim);
	dbgmsg (3, "   --use-color: ", boolConv($useColor), "\n") if (defined $useColor);
	dbgmsg (3, "   --use-ipc: ", boolConv($useIPC), "\n") if (defined $useIPC);
	dbgmsg (3, "   --work-directory: $workDir\n");
	dbgmsg (3, "   ARGV:\n", join("\n", @ARGV), "\n") if ($fileCount > 0);

	if ($showHelp != 0) {
		usage();
		exit 0;
	}

	if ($showVersion != 0) {
		infomsg ("RenRot version $VERSION\n");
		exit 0;
	}

	if ($extToProcess eq "" and ($fileCount == 0) and $subFileSet eq "") {
		fatalmsg ("Extension of files is required!\n");
		exit 1;
	}

	if ($extToProcess ne "" and ($fileCount != 0)) {
		warnmsg ("Extension of files will be ignored!\n");
	}

	if ($getOptions == 0) {
		usage();
		exit 1;
	}

	# is there ImageMagick
	if (defined isTherePackage("Image::Magick")) {
		$isThereIM = 1;
		dbgmsg (1, "We have Image::Magick package and could proceed with --contact-sheet related functionality.\n");
	}
	elsif ($cfgOpts{'contact sheet'} == 1 and not defined isTherePackage("Image::Magick")) {
		errmsg ("To use --contact-sheet related functionality you need Image::Magick package!\n");
		errmsg ("Contact Sheet generation disabled.\n\n");
	}

	# preparing Software tag according the usage or not of ImageMagick
	if ($isThereIM == 1) {
		my $imverobj = Image::Magick->new;
		my ($IMName, $IMVer, $IMrest) = split(/ /, $imverobj->Get('version'));
		$tags{'Software'}{'value'} = sprintf("RenRot v%s, ExifTool v%s, %s v%s", $VERSION, $Image::ExifTool::VERSION, $IMName, $IMVer);
		$tags{'Software'}{'group'} = 'EXIF';
		undef $imverobj;
	}
	else {
		$tags{'Software'}{'value'} = sprintf("ExifTool v%s, RenRot v%s", $Image::ExifTool::VERSION, $VERSION);
		$tags{'Software'}{'group'} = 'EXIF';
	}

	# Change user's parameter '*.ext' or 'ext' to '.ext'
	$extToProcess =~ s/^\*?\.?/\./ if ($fileCount == 0);
	dbgmsg (1, "getOptions(): Process with '$extToProcess' extension.\n");

	# Convert multiple tag parameters to tags hash
	foreach my $tagStr (@tmpTags) {
		my %tag = strToHash($tagStr);
		map { $tagsFromCli{$_} = $tag{$_} } keys %tag;
	}
}

########################################################################################
#
# trimValue() removes heading and trailing spaces
#
sub trimValue {
	my $value = shift;
	$value =~ s/\s*([^\s]+.*[^\s]+)\s*/$1/;
	return $value;
}

########################################################################################
#
# parsePair() gets (key, value) pair from the string like [multiword] key = "value"
#
sub parsePair {
	my $str = shift;
	my ($key, $value) = (undef, shift);
	if ($str =~ m/^([^=]+)=(.+)/) {
		($key, $value) = (trimValue($1), trimValue($2));
		$value =~ s/^[\'\"](.+)[\'\"]/$1/;	# trim quotes
		dbgmsg (4, "parsePair(): Parsed: '$key' <- '$value'\n");
	} elsif ($str =~ m/^([^=]+)=$/) {
		$key = trimValue($1);
		dbgmsg (4, "parsePair(): Parsed empty '$key', applying default value: ", defined $value ? "'$value'" : "undef", "\n");
	}
	return ($key, $value);
}

########################################################################################
#
# strToHash() parses given string to a hash
#
sub strToHash {
	my $str = shift;
	my $default = shift;
	my %hash;
	$str =~ s/:/=/;		# change first entrance of ':' to '='
	my ($key, $value) = parsePair($str, $default);
	if (defined $key) {
		$key =~ s/\s*[\(\[]([^\(\)\[\]]*)[\)\]]$//;
		my $group = (defined $1 and $1 ne "") ? $1 : undef;
		$hash{$key} = {value => $value, group => $group};

		# Print debug message
		$value = "" if (not defined $value);
		$group = "" if (not defined $group);
		dbgmsg (4, "strToHash(): Parsed: $key [$group] = '$value'\n");
	} else {
		warnmsg ("Invalid line format: $str\n");
	}
	return %hash;
}

########################################################################################
#
# getConfig() parses configuration file
#
sub getConfig {
	my $fc = shift;
	my $file = shift;

	my %hConfig;

	if (open (CFGFILE, "<$file")) {
		my @cfgfile = <CFGFILE>;
		unless (close (CFGFILE)) { errmsg ("$file wasn't closed!\n"); }
		$incFiles{$file} = $fc;
		my $i = 0;
		while ($i < scalar(@cfgfile)) {
			my $line = $cfgfile[$i++];

			# skip empty and comment lines
			next if (($line =~ m/^\s*$/) or ($line =~ m/^\s*#/));

			$line =~ s/#(.*)$//;				# remove trailing comments

			my ($key, $value) = parsePair($line);
			if (defined $value) {
				$key = lc($key);
				if ($key eq "include" and not $incFiles{$value}) {
					dbgmsg (2, "getConfig(): Parsing included file: '$value'\n");
					%hConfig = parseConfigFile($fc, $value, %hConfig);
				}
				$key .= sprintf("#%d#%d", $fc, $i) if (grep (/^$key$/, @multOpts));
				$hConfig{$key} = boolConverter($value);
				dbgmsg (3, "getConfig(): Parsed line($i): '$key' <- '$hConfig{$key}'\n");
			} else {
				warnmsg ("Unparsed line $i in configuration file.\n");
			}
		}
	} else {
		errmsg ("Can't open configuration file: $file\n");
	}

	return %hConfig;
}

########################################################################################
#
# parseConfigFile() parses one file to a hash and merges it with already passed
#
sub parseConfigFile {
	my $fc = shift;
	my $file = shift;
	my %hConfig = @_;
	if (-f $file) {
		my %tmpConfig = getConfig($fc + 1, $file);
		map { $hConfig{$_} = $tmpConfig{$_} } keys %tmpConfig;
	}
	return %hConfig;
}

########################################################################################
#
# parseConfig() parses user's or standart configuration files to hash
#
sub parseConfig {
	my $file = shift;

	my $home = $ENV{"HOME"};
	my @homeRC = ();
	$home = $ENV{"USERPROFILE"} if (not defined $home);

	if (defined $home and $home ne "") {
		push (@homeRC, $home . "/" . ".renrotrc");
		push (@homeRC, $home . "/" . ".renrot/.renrotrc");
		push (@homeRC, $home . "/" . ".renrot/renrot.conf");
	} else {
		warnmsg ("User's home environment variable isn't defined or empty!\n");
	}

	my @rcFiles = (
			"/etc/renrot.rc",
			"/etc/renrot/renrot.rc",
			"/etc/renrot/renrot.conf",
			"/usr/local/etc/renrot.rc",
			"/usr/local/etc/renrot/renrot.rc",
			"/usr/local/etc/renrot/renrot.conf",
			@homeRC,
		      );

	@rcFiles = ($file) if (defined $file);

	map { %cfgOpts = parseConfigFile(0, $_, %cfgOpts) } @rcFiles;
}

########################################################################################
#
# dirConv() simplifies directory name
#
sub dirConv {
	my $dirStr = shift;
	$dirStr =~ s/\/*\/\.\/\/*/\//g;		# remove dotslashes
	$dirStr =~ s/^\.\/\/*//;		# remove heading dotslash
	$dirStr =~ s/\/+$//;			# remove trailing slashes
	return $dirStr;
}

########################################################################################
#
# dirValidator() validates given string as no tree and no current directory
#
sub dirValidator {
	my $dirStr = shift;
	if ($dirStr =~ m/\// or
	    $dirStr eq "." or
	    $dirStr eq ".." or
	    $dirStr eq "") {
		return 0;
	}
	return 1;
}

########################################################################################
#
# switchColor() switches to user defined color scheme
#
sub switchColor {
	# Parse configuration file color set
	foreach my $cKey (keys %cfgOpts) {
		next if ($cKey !~ m/^color#\d+#\d+$/);	# skip not a color
		my %color = strToHash($cfgOpts{$cKey}, 'reset');
		map { $colors{$_} = $color{$_} } keys %color;
	}

	dbgmsg (1, "Switch to user defined color scheme.\n");
}

########################################################################################
#
# keywordizer() validates keywords
#
sub keywordizer {
	my $file = shift;			# keywords file
	return if (not (-R $file and -f $file and -T $file));

	dbgmsg (2, "Reading keywords from file: $file\n");

	my @result;

	my @keywordArr = getFileDataLines($file);
	for (my $i = 0; $i < scalar(@keywordArr); $i++) {
		$keywordArr[$i] =~ s/\r?\n$//;	# remove CR and LF symbols
		push (@result, trimValue($keywordArr[$i])) if ($keywordArr[$i] !~ m/^\s*$/);
	}

	return @result;
}

########################################################################################
#
# renRotProcess() renames and rotates given file set
#
sub renRotProcess {
	my $exifToolObj = shift;
	my $counterSize = shift;
	my $fileCounter = $countStart;	# file counter
	my $newFileName;		# the name file to be renamed to
	my $info;			# ImageInfo object

	my @keywordArr;			# array for keywords

	if ($cfgOpts{'keywordize'} != 0) {
		@keywordArr = keywordizer ($cfgOpts{'keywords file'});
		errmsg ("Keywords file doesn't exist!\n") if (not -e $cfgOpts{'keywords file'});
	}

	if (scalar(@keywordArr) > 0) {
		dbgmsg (2, "Keywords count: ", scalar(@keywordArr), "\n");
		if ($cfgOpts{'keywords replace'} != 0) {
			$exifToolObj->SetNewValue(Keywords => \@keywordArr);
		} else {
			$exifToolObj->SetNewValue(Keywords => \@keywordArr, AddValue => 1);
		}
	}

	# Convert trim boolean value to string
	my $trimStr = (not defined $cfgOpts{'trim'} or $cfgOpts{'trim'}) ? '-trim' : '';
	dbgmsg (1, "renRotProcess(): Trim string: '$trimStr'\n");

	dbgmsg (1, "renRotProcess(): Initializing tags ...\n");
	foreach my $key (sort (keys %tags)) {
		$exifToolObj->SetNewValue($key, $tags{$key}{value}, Group => $tags{$key}{group});
	}

	procmsg ("RENAMING / ROTATING\n");
	procmsg ("===================\n");

	my $file_num = scalar(@files);
	my $file_rem = 0;
	foreach my $file (@files) {
		$file_rem++;
		procmsg ("Processing file: ($file_rem of $file_num) $file ...\n");

		# Setup defaults
		$info = $exifToolObj->ImageInfo($file);

		# analyzing whether to rotate
		my $angleSuffix = rotateFile($exifToolObj, $info, $file, $trimStr);

		# analyzing whether and how to rename file
		$newFileName = renameFile($exifToolObj, $info, $file, $fileCounter, $counterSize, $angleSuffix);

		# to save RenRotFileNameOriginal tag we have to rewrite it each time we anyhow prosess file
		saveOurHdrs($exifToolObj, $info, $file);

		# Writing tags.
		tagWriter($exifToolObj, $newFileName) if ($noTags == 0);

		# seting mtime for the file if been asked for
		mtimeSet($exifToolObj, $info, $newFileName);

		procmsg ("\n");

		$fileCounter += $countStep;
	}
}

########################################################################################
#
# saveOurHdrs() saves our defined tags to file
#
sub saveOurHdrs {
	my $exifToolObj = shift;
	my $infoObj = shift;
	my $file = shift;

	my $fileNameOriginal = $exifToolObj->GetValue("RenRotFileNameOriginal");

	if (not defined $fileNameOriginal) {
		$tags{'RenRotFileNameOriginal'} = {value => $file, group => 'RenRot'};
		dbgmsg (2, "saveOurHdrs(): set RenRotFileNameOriginal to $file.\n");
	} else {
		$tags{'RenRotFileNameOriginal'} = {
				value => $infoObj->{"RenRotFileNameOriginal"},
				group => 'RenRot'
		};
		dbgmsg (2, "saveOurHdrs(): RenRotFileNameOriginal: $fileNameOriginal.\n");
	}

	$exifToolObj->SetNewValue(
			"RenRotFileNameOriginal",
			$tags{'RenRotFileNameOriginal'}{value},
			Group => $tags{'RenRotFileNameOriginal'}{group}
	);
}

########################################################################################
#
# rotateFile() rotates file and its thumbnail if needed, changes Orientation tag
#
sub rotateFile {
	my $exifToolObj = shift;
	my $infoObj = shift;
	my $file = shift;
	my $trimStr = shift;
	my $orientation = $exifToolObj->GetValue("Orientation", 'ValueConv');

	my $angleSuffix = "0cw";

	if ($noRotation != 0) { dbgmsg (2, "rotateFile(): No rotation asked, file orientation is left untouched.\n"); }
	elsif ( defined $rotateAngle ) {
		dbgmsg (2, "rotateFile(): We'll deal with: $file and $rotangles{$rotateAngle}.\n");
		if ($orientTag != 0) {
			rotateOrient($exifToolObj, $file, $orientation);
		} else {
			rotateImg($file, $rotangles{$rotateAngle}, $trimStr);
			rotateThumbnail($infoObj, $file, $rotangles{$rotateAngle}, $trimStr);
		}
		$angleSuffix = $rotateAngle . "cw";
	}
	elsif ( defined $rotateThumbnail ) {
		rotateThumbnail($infoObj, $file, $rotangles{$rotateThumbnail}, $trimStr);
	}
	else {
		if (defined $orientation) {
			if ( $orientation > 1 ) {
				rotateImg($file, $rotparms[$orientation - 1], $trimStr);
				rotateThumbnail($infoObj, $file, $rotparms[$orientation - 1], $trimStr);
				$angleSuffix = $angles[$orientation - 1];
			}
			elsif ( $orientation == 1 ) {
				dbgmsg (2, "rotateFile(): No need to rotate, orientation is: Horizontal (normal).\n");
			}
			else {
				errmsg ("Something wrong, orientation low than 1: $orientation.\n");
			}
		}
		else {
			warnmsg ("Orientation tag is absent!\n");
		}
	}

	return $angleSuffix;
}

########################################################################################
#
# renameFile() renames file according to user request and EXIF data
#
sub renameFile {
	my $exifToolObj = shift;
	my $infoObj = shift;
	my $file = shift;
	my $fileCounter = shift;
	my $counterSize = shift;
	my $angleSuffix = shift;

	my $newFileName;
	my $unixTime = getUnixTime(getTimestamp($exifToolObj, $infoObj));

	if ($noRename != 0) {
		dbgmsg (2, "renameFile(): No renaming asked, filename is left untouched.\n");
		$newFileName = $file;
		$filenameshash{$newFileName} = $unixTime;
	} else {
		my $ext = ($file =~ m/(\.[^\.]+)$/) ? $1 : "";
		my $extLen = length($ext);

		$newFileName = template2name($exifToolObj,
					     $infoObj,
					     $cfgOpts{'name template'},
					     $fileCounter,
				     	     $file,
					     $counterSize,
					     $angleSuffix);
		if ($filenameshash{$newFileName . $ext}) {
			$newFileName .= "." . sprintf($counterSize, $fileCounter) . $ext;
		} else {
			$newFileName .= $ext;
		}

		$filenameshash{$newFileName} = $unixTime;

		if ($file ne $newFileName) {
			if (-f $newFileName) {
				fatalmsg ("File $newFileName already exists!\n"), die;
			}
			if ($dryRun == 0) { rename ($file, $newFileName)
				|| ( fatalmsg ("Unable to rename $file -> $newFileName.\n"), die );
			}
			procmsg ("Renamed: $file -> $newFileName\n");
		} else { warnmsg ("No renaming needed for $newFileName, it looks as needed!\n"); }
	}

	return $newFileName;
}

########################################################################################
#
# getFileData() gets data from a given file in one-line string
#
sub getFileData {
	my $file = shift;
	my @result = getFileDataLines($file);
	return join ("", @result) if (scalar(@result) > 0);
	return undef;
}

########################################################################################
#
# getFileDataLines() gets data from a given file in array of lines
#
sub getFileDataLines {
	my $file = shift;

	if (not defined $file or $file eq "") {
		warnmsg ("Can't read file with empty name!\n");
		return;
	}

	if (open(XXXFILE, "<$file")) {
		binmode XXXFILE;
		my @xxxData = <XXXFILE>;
		unless (close(XXXFILE)) { errmsg ("$file wasn't closed!\n"); }
		return @xxxData;
	}

	warnmsg ("Can't read file: $file!\n");
	return;
}

########################################################################################
#
# mtimeSet() sets mtime for the given file
#
sub mtimeSet {
	my $exifToolObj = shift;
	my $infoObj = shift;
	my $file = shift;
	if ($cfgOpts{'mtime'} != 0) {
		my $mTime = getUnixTime(getTimestamp($exifToolObj, $infoObj));
		if ($dryRun == 0) { utime $mTime, $mTime, $file; }
		else { procmsg ("Setting mtime.\n"); }
		dbgmsg (2, "mtimeSet(): Changing mtime for $file OK.\n");
	}
}

########################################################################################
#
# tagWriter() writes couple of tags defined via configuration file and command line
#
sub tagWriter {
	my $exifToolObj = shift;
	my $file = shift;

	# writing the changes to the EXIFs
	if ($dryRun == 0) { exifWriter($exifToolObj, $file); }
	else { procmsg ("Writing user defined EXIF tags to $file.\n"); }
}

########################################################################################
#
# exifWriter() applies EXIF info, set by SetNewValue, to the image taken from
# the file, and writes the result to the same file.
#
sub exifWriter {
	my $exifToolObject = shift;
	my $fileRes = shift;		# the file the *image* taken from

	my $result = $exifToolObject->WriteInfo($fileRes);
	if ($result == 1) {
		dbgmsg (2, "exifWriter(): Writing to $fileRes seems to be OK.\n");
	} elsif ($result == 2) {
		warnmsg ("No EXIF difference. No EXIF was written.\n");
	} else {
		my $errorMessage   = $exifToolObject->GetValue('Error');
		my $warningMessage = $exifToolObject->GetValue('Warning');
		if ( defined $errorMessage ) { errmsg ("ExifTool: $errorMessage\n"); }
		if ( defined $warningMessage ) { warnmsg ("ExifTool: $warningMessage\n"); }
	}
	return $result;
}

########################################################################################
#
# aggregationProcess() aggregates files to separate directories by request
#
sub aggregationProcess {
	return if ($cfgOpts{'aggregation mode'} eq "none");

	my $exifToolObj = shift;
	my $counterSize = shift;
	my $file;
	my $info;
	my $NewDir;
	my $file_num = scalar(keys(%filenameshash));
	my $file_rem = 0;

	procmsg ("AGGREGATION\n");
	procmsg ("===========\n");

	if ($cfgOpts{'aggregation mode'} eq "template") {
		dbgmsg (1, "aggregationProcess(): Template: $cfgOpts{'aggregation template'}\n");
		my $fileCounter = $countStart;

		foreach $file (sort (keys %filenameshash)) {
			$file_rem++;
			dbgmsg (4, "aggregationProcess(): Processing ($file_rem of $file_num) file: $file\n");
			$info = $exifToolObj->ImageInfo($file);
			$NewDir = template2name($exifToolObj,
						$info,
						$cfgOpts{'aggregation template'},
						$fileCounter,
						$file,
						$counterSize,
						"0cw");
			aggregateFile($file, $NewDir) if ($dryRun == 0);

			procmsg ("Aggregate: ($file_rem of $file_num) $file -> $NewDir\n", "\n");
			$fileCounter += $countStep;
		}
	} elsif ($cfgOpts{'aggregation mode'} eq "delta") {
		my $DirCounter = 1;
		my $timestampPrev;
		my $filePrev;
		my $filetmp;

		foreach $file (sort (keys %filenameshash)) {
			$filetmp = $file;
			$file_rem++;
			dbgmsg (4, "aggregationProcess(): Processing ($file_rem of $file_num) file: $file\n");

			if ($DirCounter == 1) {
				$timestampPrev = $filenameshash{$filetmp};
				$filePrev = $filetmp;
				$NewDir = $cfgOpts{'aggregation directory'} . "." . sprintf($counterSize, $DirCounter);
				$DirCounter++;
				aggregateFile($file, $NewDir) if ($dryRun == 0);
			} else {
				# Check for new direcroty creation
				if (($filenameshash{$filetmp} - $timestampPrev) > $cfgOpts{'aggregation delta'}) {
					$NewDir = $cfgOpts{'aggregation directory'} . "." . sprintf($counterSize, $DirCounter);
					$DirCounter++;
				}
				aggregateFile($file, $NewDir) if ($dryRun == 0);
				$timestampPrev = $filenameshash{$filetmp};
			}
			procmsg ("Aggregate: ($file_rem of $file_num) $file -> $NewDir\n", "\n");
		}
	} else {
		errmsg ("Aggregation mode $cfgOpts{'aggregation mode'} isn't implemented!\n");
	}
}

########################################################################################
#
# contactSheetGenerator(): requires -e
#
if ($isThereIM) {
	sub contactSheetGenerator {
		return if (not $cfgOpts{'contact sheet'});
		my $exifToolObj = shift;
		my $workdir = $cfgOpts{'contact sheet dir'} . "/";
		my $file;
		my $info;
		my $infothm;
		my $ThumbnailOriginal;
		my $width;
		my $height;
		my $size = 0;
		my @thumbnailes;
		my @thumbnailes_sorted;
		my $orientation;
		my $filefull;

		use Image::Magick;

		if ( not -d $workdir ) { mkdir $workdir; }

		use File::Copy;

		procmsg ("CONTACT SHEET GENERATION\n");
		procmsg ("========================\n");

		foreach $file (keys %filenameshash) { # no sort since it'll be sorted below
			$info = $exifToolObj->ImageInfo($file);
			$orientation = $exifToolObj->GetValue("Orientation", 'ValueConv');
			$filefull = $file;

			if ( $contactSheetThm != 0
			     and defined $orientation and $orientation > 1 ) {
				$filefull = rotmont ( $file, $rotorient{$orientation}, $workdir );
			}
			elsif ( $contactSheetThm != 0
			     and defined $orientation and $orientation == 1 ) {	# we need this since rotated img'll be @ $workdir, but others in current
		     		$ThumbnailOriginal = $workdir . $file;
		     		copy($file, $ThumbnailOriginal) or die "copy failed: $!";
				$filefull = $ThumbnailOriginal;
			}
			elsif ( $contactSheetThm == 0 and defined ${$$info{ThumbnailImage}} ) {
				$ThumbnailOriginal = $workdir . $file;
				unless ( open ( OLDTHUMBNAIL, ">$ThumbnailOriginal" ) ) {
					die "$ThumbnailOriginal wasn't opened!\n";
				}
				binmode OLDTHUMBNAIL;
				print OLDTHUMBNAIL ${$$info{ThumbnailImage}};
				unless ( close ( OLDTHUMBNAIL ) ) { warn "$ThumbnailOriginal wasn't closed!\n"; }

				if ( not defined $orientation ) {
					$orientation = $exifToolObj->GetValue("Rotation", 'ValueConv');
				}

				if ( defined $orientation and $orientation > 1 ) {
					$filefull = rotmont ( $ThumbnailOriginal , $orientation, "" );
				}
				else {
					$filefull = $ThumbnailOriginal;
				}
			}
			elsif ( $contactSheetThm == 0 and not defined ${$$info{ThumbnailImage}}) {
				procmsg ( "WARNING: $filefull has no ThumbnailImage tag. Stub thumbnail image'll be used.\n");
				if ( not -f $workdir."thmbstub.jpg" ) {
					thmbgen($workdir,"thmbstub.jpg");
					procmsg ( "Stub thumbnail image've been created.\n" );
				}
				copy($workdir."thmbstub.jpg",$workdir.$file);
				$filefull = $workdir.$file;
			}

			$infothm = $exifToolObj->ImageInfo($filefull);
			$width = $exifToolObj->GetValue("ImageWidth");
			$height = $exifToolObj->GetValue("ImageHeight");
			if ( $width > $size ) { $size = $width; }
			if ( $height > $size ) { $size = $height; }

			push (@thumbnailes, $filefull);
		}
		@thumbnailes_sorted = sort {$a cmp $b} @thumbnailes;

		dbgmsg (3, "contactSheetGenerator(): contact sheet background = \"$cfgOpts{'contact sheet background'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet bordercolor = \"$cfgOpts{'contact sheet bordercolor'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet mattecolor = \"$cfgOpts{'contact sheet mattecolor'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet font = \"$cfgOpts{'contact sheet font'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet label = \"$cfgOpts{'contact sheet label'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet frame = \"$cfgOpts{'contact sheet frame'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet pointsize = \"$cfgOpts{'contact sheet pointsize'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): contact sheet shadow = \"$cfgOpts{'contact sheet shadow'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): title = \"$cfgOpts{'contact sheet title'}\"\n");
		dbgmsg (3, "contactSheetGenerator(): tile = \"$cfgOpts{'contact sheet tile'}\"\n");

		# here it's iteration by tile
		my ($tileX, $tileY) = split ("x",$cfgOpts{'contact sheet tile'});
		my $tileMul = $tileX * $tileY;
		my $csIterationNumber = $#thumbnailes_sorted + 1;
		my $csFullIterations = int($csIterationNumber/$tileMul);
		my $csIteration = 0;
		my $csIterator = 0;
		my $csIter = 0;
		my $readres;
		my $image;
		my $writeres;
		my $montage;
		my $montagename;
		my $infoMontage;
		my @left_up_row = ('RenRot (c)',$homeURL);

		if ( $csIterationNumber > $tileX * $tileY ) {
			for ( ; $csIterator < $csFullIterations ; $csIterator++ ) {
				$image = Image::Magick->new;
				$montagename = $cfgOpts{'contact sheet file'} . "-" . $csIterator . ".jpg";
				for ($csIter = $csIterator * $tileMul ; $csIter < ($csIterator * $tileMul + $tileMul) ; $csIter++) {
					$readres = $image->Read("jpg:".$thumbnailes_sorted[$csIter]);
					if ( not $readres ) { dbgmsg (4,"$thumbnailes_sorted[$csIter] was successfully red.\n"); }
					else { errmsg ("Image::Magick error: $readres\n\n"); }
				}
				dbgmsg (1,"$csIterator montage is started, wait a bit please ...\n");
				$montage = $image->Montage(background => "#" . $cfgOpts{'contact sheet background'},
							bordercolor => "#" . $cfgOpts{'contact sheet bordercolor'},
							mattecolor => "#" . $cfgOpts{'contact sheet mattecolor'},
							font => $cfgOpts{'contact sheet font'},
							fill => "#" . $cfgOpts{'contact sheet fill'},
							label => $cfgOpts{'contact sheet label'},
							frame => $cfgOpts{'contact sheet frame'},
							geometry => $size . "x" . $size . "+4+4",
							pointsize => $cfgOpts{'contact sheet pointsize'},
							shadow => $cfgOpts{'contact sheet shadow'},
							title => $cfgOpts{'contact sheet title'},
							tile => $cfgOpts{'contact sheet tile'},
							stroke => 'none');
			
				if ( not ref($montage) ) { errmsg ("Image::Magick error: $montage\n\n"); }
				else { dbgmsg (1,"$csIterator montage've finished successfully.\n"); }
				$montage->Set(filename=>'jpg:'.$montagename, quality=>95, interlace=>'Partition',gravity=>'Center',stroke=>'none');
				$montage->Annotate(font=>$cfgOpts{'contact sheet font'}, pointsize=>9, fill=>'lightgray', text=>$left_up_row[0], x=>1, y=>10);
				$montage->Annotate(font=>$cfgOpts{'contact sheet font'}, pointsize=>9, fill=>'lightgray', text=>$left_up_row[1], x=>1, y=>20);
				$writeres = $montage->Write();
				if ( not $writeres ) { dbgmsg (1,"Successfully written $montagename file.\n\n"); }
				else { errmsg ("Image::Magick error: $writeres\n\n"); }
				undef $image;
				$infoMontage = $exifToolObj->ImageInfo($montagename);
				# to save RenRotFileNameOriginal tag we have to rewrite it each time we anyhow prosess file
				saveOurHdrs($exifToolObj, $infoMontage, $montagename);
				# Writing tags.
				tagWriter($exifToolObj, $montagename);

			}
		}

		$image = Image::Magick->new;
		$montagename = $cfgOpts{'contact sheet file'} . "-" . $csIterator . ".jpg";
		for ($csIteration = $csIterator-- * $tileMul; $csIteration < $csIterationNumber ; $csIteration++) {
			$readres = $image->Read("jpg:".$thumbnailes_sorted[$csIteration]);
			if ( not $readres ) { dbgmsg (4,"$thumbnailes_sorted[$csIteration] was successfully red.\n"); }
			else { errmsg ("Image::Magick error: $readres\n\n"); }
		}

		dbgmsg (1,++$csIterator . " montage is started, wait a bit please ...\n");
		
		# the final invocation of ->Montage() method for the the rest of files didn't fit previous loop	->Montage() calls
		# when  $csIterationNumber < $tileX * $tileY 
		$montage = $image->Montage(background => "#" . $cfgOpts{'contact sheet background'},
					bordercolor => "#" . $cfgOpts{'contact sheet bordercolor'},
					mattecolor => "#" . $cfgOpts{'contact sheet mattecolor'},
					font => $cfgOpts{'contact sheet font'},
					fill => "#" . $cfgOpts{'contact sheet fill'},
					label => $cfgOpts{'contact sheet label'},
					frame => $cfgOpts{'contact sheet frame'},
					geometry => $size . "x" . $size . "+4+4",
					pointsize => $cfgOpts{'contact sheet pointsize'},
					shadow => $cfgOpts{'contact sheet shadow'},
					title => $cfgOpts{'contact sheet title'},
					tile => $cfgOpts{'contact sheet tile'},
					stroke => 'none');
	
		if ( not ref($montage) ) { errmsg ("Image::Magick error: $montage\n\n"); }
		else { dbgmsg (1,"Montage've finished successfully.\n"); }

		undef $image;
		$montage->Set(filename=>'jpg:'.$montagename, quality=>95, interlace=>'Partition',gravity=>'Center',stroke=>'none');
		$montage->Annotate(font=>$cfgOpts{'contact sheet font'}, pointsize=>9, fill=>'lightgray', text=>$left_up_row[0], x=>1, y=>10);
		$montage->Annotate(font=>$cfgOpts{'contact sheet font'}, pointsize=>9, fill=>'lightgray', text=>$left_up_row[1], x=>1, y=>20);
		$writeres = $montage->Write();
		if ( not $writeres ) { dbgmsg (1,"Successfully written $montagename file.\n\n"); }
		else { errmsg ("Image::Magick error: $writeres\n\n"); }

		$infoMontage = $exifToolObj->ImageInfo($montagename);
		# to save RenRotFileNameOriginal tag we have to rewrite it each time we anyhow prosess file
		saveOurHdrs($exifToolObj, $infoMontage, $montagename);
		# Writing tags.
		tagWriter($exifToolObj, $montagename);

		chdir $workdir;
		unlink <*>;
		chdir "..";
		rmdir $workdir;
	}

	# thumbnail stub generator
	sub thmbgen {
		my $wrkdir = shift;
		my $thmbname = shift;
		$thmbname = $wrkdir.$thmbname;
		my $size = "160x120";
		my $text = "thumbnail\n\nNA";

		my $thmb = Image::Magick->new;

		$thmb->Set(size=>$size,filename=>$thmbname, quality=>95, interlace=>'Partition');
		$thmb->ReadImage('gradient:#ffffff-#909090');
		$thmb->Annotate(pointsize=>25, fill=>'#888888', font=>$cfgOpts{'contact sheet font'}, text=>$text, gravity=>'Center');
		my $thmbnum = $thmb->Write();

		if ( $thmbnum ) { errmsg ("$thmbnum\n\n"); }

		undef $thmb;
	}

	# rotmont() rotates thumbnails for montage
	sub rotmont {
		my $fileorig = shift;	# pathless filename of the rotated file
		my $angle = shift;
		my $theworkdir = shift;
		my $rotate = Image::Magick->new;
		my $res = $theworkdir.$fileorig;

		$rotate->Read("JPEG:".$fileorig);
		$rotate->Rotate(degrees=>$angle);
		$rotate->Write(filename=>"JPEG:".$res, quality=>95, compression=>'JPEG2000');
		undef $rotate;

		return $res;
	}
}

########################################################################################
#
# makeDir() makes one level directory
#
sub makeDir {
	my $newDir = shift;
	if (not -d $newDir) {
		unless (mkdir $newDir) { errmsg ("$newDir wasn't created!\n"); }
	}
}

########################################################################################
#
# aggregateFile() moves file to new directory
#
sub aggregateFile {
	my $file = shift;
	my $NewDir = shift;

	if ($cfgOpts{'aggregation virtual'} == 0) {
		makeDir($NewDir);
		my $newfilename = $NewDir . "/" . $file;
		rename ($file, $newfilename) || ( fatalmsg ("$file -> $newfilename\n"), die );
	} else {
		makeDir($cfgOpts{'aggregation virtual directory'});
		$NewDir = $cfgOpts{'aggregation virtual directory'} . "/" . $NewDir;
		makeDir($NewDir);
		my $newfilename = $NewDir . "/" . $file;
		if (not -l $newfilename) {
			my $symlink = "../../" . $file;
			symlink ($symlink, $newfilename) || ( fatalmsg ("While linking $file -> $newfilename\n"), die );
		}
		else {
			procmsg ("Link $newfilename already exists.\n");
		}
	}
}

########################################################################################
#
# timeNow() returns timestamp in form YYYYmmddHHMMSS
#
sub timeNow {
	my $date = localtime();
	my $timeNow = sprintf("%.4d%.2d%.2d%.2d%.2d%.2d",
		$$date[5] + 1900, $$date[4] + 1, $$date[3],
		$$date[2], $$date[1], $$date[0]);
	return $timeNow;
}

########################################################################################
#
# timeValidator() returns correctness of timestamp in form YYYYmmddHHMMSS
#
sub timeValidator {
	my $timestamp = shift;

	# check length (14)
	return 1 if (length($timestamp) != 14);

	my @tm = ($timestamp =~ m/(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
	return 1 unless @tm == 6;
	dbgmsg (4, "timeValidator(): @tm\n");

	if (
		# check year
		($tm[0] < 1900) or
		# check month
		(($tm[1] > 12) or ($tm[1] < 1)) or
		# check day
		(($tm[2] > 31) or ($tm[2] < 1)) or
		# check hour, minute, second
		($tm[3] > 23) or ($tm[4] > 59) or ($tm[5] > 59)
	   ) {
		return 1;
	}

	return 0;
}

########################################################################################
#
# getTimestamp() returns EXIF timestamp in form YYYYmmddHHMMSS if exists, otherwise
# it returns timeNow()
#
sub getTimestamp {
	my $exifToolObj = shift;
	my $infoObj = shift;

	my $timestamp;

	if (defined $infoObj->{"DateTimeOriginal"} and not timeValidator($infoObj->{"DateTimeOriginal"})) {
		$timestamp = $infoObj->{"DateTimeOriginal"};
	}
	elsif (defined $infoObj->{"FileModifyDate"} and not timeValidator($infoObj->{"FileModifyDate"})) {
		$timestamp = $infoObj->{"FileModifyDate"};
	}
	else {
		$timestamp = timeNow();
		$exifToolObj->SetNewValue('FileModifyDate', $timestamp, Group => 'File');
		warnmsg ("EXIF timestamp isn't correct, using timeNow()!\n");
	}

	return $timestamp;
}

########################################################################################
#
# getUnixTime() converts timestamp to unix time form
#
sub getUnixTime {
	my $timestamp = shift;
	my @tm = ($timestamp =~ m/(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
	$tm[0] -= 1900;     # convert year
	$tm[1] -= 1;        # convert month
	@tm = reverse @tm;  # change to order required by timelocal()
	return Time::Local::timelocal(@tm);
}

########################################################################################
#
# rotateOrient() rotates image by changing Orientation tag. No real rotation
# will be made.
#
sub rotateOrient {
	my $exifToolObj = shift;
	my $fileOrient = shift;
	my $orientation = shift;

	dbgmsg (4, "rotateOrient(): Original Orientation: $orientation\n");
	my $angleTmp = $rotorient{$orientation};
	if (not defined $angleTmp) {
		errmsg ("Operation not permited for mirror type orientation.\n");
		return;
	}

	$angleTmp += $rotateAngle;
	$angleTmp -= 360 if ($angleTmp >= 360);

	$orientation = $rotorientrev{$angleTmp};
	dbgmsg (4, "rotateOrient(): New Orientation: $orientation\n");

	$exifToolObj->SetNewValue("Orientation", $orientation, Type => 'ValueConv');
	if ($dryRun == 0) { exifWriter($exifToolObj, $fileOrient); }
	else { procmsg ("Rotating Orientation tag value.\n"); }
}

########################################################################################
#
# rotateImg() rotates the image file by given angle
#
sub rotateImg {
	my $oldfile = shift;			# original name to transform with jpegtran
	my $origfile = $oldfile . "_orig";	# backup original name
	my $newfile = $oldfile . "_rotated";	# temporay name to store rotated file
	my @addon = @_;				# the switches for jpegtran to transform the image

	# jpegtran the image
	my $cmd = "jpegtran -copy none @addon -outfile \"$newfile\" \"$oldfile\"";
	dbgmsg (3, "rotateImg(): $cmd\n");
	system $cmd || ( fatalmsg ("System $cmd failed: $?\n"), die );

	# preparing to write tags to the just rotated file
	my $exifAfterRot = new Image::ExifTool;
	$exifAfterRot->Options(Binary => 1);
	$exifAfterRot->SetNewValuesFromFile($oldfile, '*:*');
	$exifAfterRot->SetNewValue("Orientation", 1, Type => 'ValueConv');

	if ($backup != 0) {
		rename ($oldfile, $origfile) || ( fatalmsg ("$oldfile -> $origfile\n"), die );
	}
	rename ($newfile, $oldfile)  || ( fatalmsg ("$newfile -> $oldfile\n"), die );

	# writing the changes to the EXIFs
	exifWriter($exifAfterRot, $oldfile);
}

########################################################################################
#
# thumbWriter() writes binary data as thumbnail to given file
#
sub thumbWriter {
	my $file = shift;
	my $thethumb = shift;

	# preparing to write thumbnale to the just rotated file
	my $exifThumbnailed = new Image::ExifTool;
	$exifThumbnailed->Options(Binary => 1);
	$exifThumbnailed->SetNewValue("ThumbnailImage", $thethumb, Type => 'ValueConv');

	# writing the changes to the EXIFs
	exifWriter($exifThumbnailed, $file);
}

########################################################################################
#
# rotateThumbnail() rotates thumbnail only, where the file was rotated but
# thumbnail was left untouched
#
sub rotateThumbnail {
	my $infoObj = shift;
	my $file = shift;	# file, which thumbnale to transform with jpegtran
	my @addon = @_;		# the switches for jpegtran to rotate the thumbnail

	if (not defined ${$$infoObj{ThumbnailImage}}) {
		warnmsg ("No thumbnail found.\n");
		return;
	}

	my $origThumb = ${$$infoObj{ThumbnailImage}};

	if ($cfgOpts{'use ipc'} == 0) {
		# extracting the thumbnail image
		my $ThumbnailOriginal = $file . "_thumborig";
		unless ( open ( OLDTHUMBNAIL, ">$ThumbnailOriginal" ) ) {
			errmsg ("$ThumbnailOriginal wasn't opened!\n");
		}
		binmode OLDTHUMBNAIL;
		print OLDTHUMBNAIL $origThumb;
		unless ( close ( OLDTHUMBNAIL ) ) { warnmsg ("$ThumbnailOriginal wasn't closed!\n"); }

		# rotating the thumbnail
		my $ThumbnailOriginalRotated = $ThumbnailOriginal . "_rotated";
		my $cmd = "jpegtran -copy none @addon -outfile \"$ThumbnailOriginalRotated\" \"$ThumbnailOriginal\"";
		dbgmsg (3, "rotateThumbnail(): $cmd\n");
		system $cmd || ( fatalmsg ("System $cmd failed: $?\n"), die );

		# write the just rotated thumbnail back to file
		thumbWriter($file, getFileData($ThumbnailOriginalRotated));

		unlink ($ThumbnailOriginalRotated) || ( fatalmsg ("While killing $ThumbnailOriginalRotated.\n"), die );
		unlink ($ThumbnailOriginal) || ( fatalmsg ("While killing $ThumbnailOriginal.\n"), die );
	} else {
		my $cmd = "jpegtran -copy none @addon";
		dbgmsg (3, "rotateThumbnail(): $cmd\n");

		# write the just rotated thumbnail back to file
		thumbWriter($file, piper($origThumb, $cmd));
	}
}

########################################################################################
#
# piper() opens two pipes for process object via cmd
#
sub piper {
	use FileHandle;
	use IPC::Open2;

	my $pipeObj = shift;	# the object to be processed via pipe
	my $pipeCmd = shift;	# the pipe command

	local (*READ_FROM_FH, *WRITE_TO_FH);	# file handlers
	unless (open2(\*READ_FROM_FH, \*WRITE_TO_FH, $pipeCmd)) {
		errmsg ("Unable to create the pipe.\n");
	}

	binmode WRITE_TO_FH;
	print WRITE_TO_FH $pipeObj;

	unless (close(WRITE_TO_FH)) { warnmsg ("WRITE handle wasn't closed!\n"); };

	binmode READ_FROM_FH;
	my @pipedArr = <READ_FROM_FH>;

	unless (close(READ_FROM_FH)) { warnmsg ("READ handle wasn't closed!\n"); };

	return join("", @pipedArr);
}

########################################################################################
#
# usage() prints the instructions how to use the script
#
sub usage {
infomsg (
"Usage:	renrot 	<--extension EXTENSION> [--quiet] [--no-rotate] [--no-rename]
		[--name-template TPL] [--comment-file FILE] [--work-directory DIR]
		[[--] FILE1 FILE2 ...]

Options:
  -c, --config-file <FILE>	configuration file to use
  -d, --work-directory <DIR>	set working directory
      --exclude <FILE> ...	files exclude from processing; no wildcards
      --sub-fileset <FILE>	read names of the files to be processed from
                                FILE
  -e, --extension <EXTENSION>	extension of files to process: JPG, jpeg, ...

Renaming options:
  -n, --name-template <TPL>	filename template (see manual for details)
      --no-rename		do not rename files (default is to rename)
      --counter-fixed-field (*)	set fixed field width for counter (used in
                                templates)
      --counter-start <NUMBER>	start value for the counter of renamed files
      --counter-step <NUMBER>	increment value for the counter of renamed
                                files

Rotating options:
  -r, --rotate-angle <ANGLE>	angle to rotate files and thumbnails by 90,
                                180, 270
      --rotate-thumb <ANGLE>	rotate only thumbnails by 90, 180, 270
      --only-orientation	change Orientation tag (no real rotation)
      --no-rotate		do not rotate (default is to rotate)
      --trim (*)		pass -trim to jpegtran
      --mtime (*)		set file mtime according to DateTimeOriginal
                                tag

Keywordizing options:
      --keywordize (*)		set Keywords tag
      --keywords-replace (*)	replace Keywords tag rather than add values to
                                it
  -k, --keywords-file <FILE>	read keywords from FILE

Aggregating options:
      --aggr-mode <MODE>	run aggregation (MODE: none, delta, template)
      --aggr-delta <INTERVAL>	aggregation time delta
      --aggr-directory <DIR>	aggregation directory name
  -a, --aggr-template <TPL>	aggregation template (see manual for details)
      --aggr-virtual (*)	virtual aggregation (symlinks instead of files)
      --aggr-virtual-directory <DIR> root directory for virtual aggregation

Contact Sheet options:
	--contact-sheet		create the contact sheet
	--contact-sheet-tile	tile in montage, MxN
	--contact-sheet-title	set title of the montage
	--contact-sheet-file <FILE>
                                name of the montage files
	--contact-sheet-dir <DIR>
                                temporary montage dir
	--contact-sheet-thm	files for montage are already thumbnails

Tag writing options:
      --comment-file <FILE>	file with text to put into Commentary tag
      --user-comment <COMMENT>	file with text to put into UserComment tag
  -t, --tag <TAG> ...		existing EXIF tag to set in renamed files
      --no-tags			do not write tags

Colorizing options:
      --use-color (*)		colorized output

Misc options:
      --dry-run			do nothing, only print would have been done
      --use-ipc (*)		rotate thumbnail via pipe, rather than via file
  -v				increment debugging level by 1
  -h, --help			display this help and exit
      --version			output version and exit

(*) The options marked with this sign do not take arguments and can be negated,
i.e. prefixed by 'no'. E.g. '--mtime' sets file mtime value, while '--nomtime'
or '--no-mtime' disables setting it.
");
}

########################################################################################
#
# template2name() builds file name according to the template
#
sub template2name {
	my $exifToolObj = shift;
	my $infoObj = shift;
	my $template = shift;	# the template to be used
	my $fileNo = shift;	# counter for %c
	my $fileName = shift;	# file name for %n and %e
	my $counterSize = shift;
	my $angleSuffix = shift;# suffix to add to the end of the rotated files
	my ($base, $ext);	# file name %n and extension %e

	if ($fileName =~ m/^(.*)\.([^\.]+)$/) {
		$base = $1;
		$ext = $2;
	}
	else {
		$base = $fileName;
		$ext = '';
	}

	if (not defined $template) {
		fatalmsg ("Template isn't given!\n"), die;
	}

	my $timestamp = getTimestamp($exifToolObj, $infoObj);
	my @tm = ($timestamp =~ m/(\d\d(\d\d))(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
	dbgmsg (4, "template2name(): tm: @tm\n");

	my $ExposureTime = "";
	my $FileNumber = 'NA';
	my $FNumber = "";
	my $ISO = "";
	my $WhiteBalance = "";
	my $fileNameOriginal = "";
	my $fileNameOriginalCounter = "";		# we can't use 0 as default value
	my $fileNameOriginalExtensionLess = "";

	if (defined $infoObj->{"FileNumber"}) {
		$FileNumber = $infoObj->{"FileNumber"};
	}

	if (defined $infoObj->{"ExposureTime"}) {
		$ExposureTime = "E" . $infoObj->{"ExposureTime"};
		$ExposureTime =~ s/\//by/g;
	}

	if (defined $infoObj->{"FNumber"}) {
		$FNumber = "F" . $infoObj->{"FNumber"};
	}

	if (defined $infoObj->{"ISO"}) {
		$ISO = "I" . $infoObj->{"ISO"};
	}

	if (defined $infoObj->{"WhiteBalance"}) {
		$WhiteBalance = "W" . $infoObj->{"WhiteBalance"};
		$WhiteBalance =~ s/[\s()]//g;
	}

	if (defined $infoObj->{"RenRotFileNameOriginal"}) {
		$fileNameOriginal = $infoObj->{"RenRotFileNameOriginal"};
		# file name starts with letters and ends with digits
		if ($fileNameOriginal =~ m/^[[:alpha:]\-_]*(\d+)(\.[^\.]+)?$/) {
			$fileNameOriginalCounter = $1;
		}
		if ($fileNameOriginal =~ m/^(.*)\.([^\.]+)$/) {
			$fileNameOriginalExtensionLess = $1;
		}
	}

	my @templatearea = split (//, $template);
	my %templatehash = (
				'%' => "%",
				'a' => $angleSuffix,
				'C' => $fileNameOriginalCounter,
				'c' => sprintf($counterSize, $fileNo),
				'd' => $tm[3],
				'E' => $ExposureTime,
				'e' => $ext,
				'F' => $FNumber,
				'H' => $tm[4],
				'I' => $ISO,
				'i' => $FileNumber,
				'M' => $tm[5],
				'm' => $tm[2],
				'n' => $base,
				'O' => $fileNameOriginalExtensionLess,
				'o' => $fileNameOriginal,
				'S' => $tm[6],
				'W' => $WhiteBalance,
				'Y' => $tm[0],
				'y' => $tm[1],
			   );
	my $thename = "";

	my $substroffset = 0;
	my $substrchar;

	dbgmsg (4, "template2name(): '$template' (length: " . scalar(@templatearea) .")\n");
	while ($substroffset < scalar(@templatearea)) {
		$substrchar = $templatearea[$substroffset++];
		if ($substrchar eq "%" and $substroffset < scalar(@templatearea)) {
			$substrchar = $templatearea[$substroffset++];
			if ( defined $templatehash{$substrchar} ) {
				$thename .= $templatehash{$substrchar};
			}
		}
		else { $thename .= $substrchar; }
	}

	return $thename;
}

########################################################################################
#
# MAIN() renames and rotates given files
#

getOptions();
parseConfig($configFile);
switchColor();

# redefining options set in configuration file with set via CLI ones
$cfgOpts{'aggregation delta'}	= $aggrDelta if (defined $aggrDelta);
$cfgOpts{'aggregation directory'}	= $aggrDir if (defined $aggrDir);
$cfgOpts{'aggregation mode'}	= $aggrMode if (defined $aggrMode);
$cfgOpts{'aggregation template'}	= $aggrTemplate if (defined $aggrTemplate);
$cfgOpts{'aggregation virtual'}	= $aggrVirtual if (defined $aggrVirtual);
$cfgOpts{'aggregation virtual directory'}	= $aggrVirtDir if (defined $aggrVirtDir);
$cfgOpts{'keywordize'}		= $keywordize if (defined $keywordize);
$cfgOpts{'keywords file'}	= $keywordsFile if (defined $keywordsFile);
$cfgOpts{'keywords replace'}	= $keywordsReplace if (defined $keywordsReplace);
$cfgOpts{'mtime'}		= $mtime if (defined $mtime);
$cfgOpts{'name template'}	= $nameTemplate if (defined $nameTemplate);
$cfgOpts{'trim'}		= $trim if (defined $trim);
$cfgOpts{'use color'}		= $useColor if (defined $useColor);
$cfgOpts{'use ipc'}		= $useIPC if (defined $useIPC);
$cfgOpts{'contact sheet'}	= $contactSheet if (defined $contactSheet);
$cfgOpts{'contact sheet tile'}	= $contactSheetTile if (defined $contactSheetTile);
$cfgOpts{'contact sheet title'}	= $contactSheetTitle if (defined $contactSheetTitle);
$cfgOpts{'contact sheet file'}	= $contactSheetFile if (defined $contactSheetFile);
$cfgOpts{'contact sheet dir'}	= $contactSheetDir if (defined $contactSheetDir);
$cfgOpts{'contact sheet background'}	= $contactSheetBg if (defined $contactSheetBg);
$cfgOpts{'contact sheet bordercolor'}	= $contactSheetBd if (defined $contactSheetBd);
$cfgOpts{'contact sheet mattecolor'}	= $contactSheetMt if (defined $contactSheetMt);
$cfgOpts{'contact sheet fill'}		= $contactSheetFl if (defined $contactSheetFl);
$cfgOpts{'contact sheet font'}		= $contactSheetFn if (defined $contactSheetFn);
$cfgOpts{'contact sheet label'}		= $contactSheetLb if (defined $contactSheetLb);
$cfgOpts{'contact sheet frame'}		= $contactSheetFr if (defined $contactSheetFr);
$cfgOpts{'contact sheet pointsize'}	= $contactSheetPntSz if (defined $contactSheetPntSz);
$cfgOpts{'contact sheet shadow'}	= $contactSheetShadow if (defined $contactSheetShadow);

dbgmsg (1, "main(): Show what would have been happened (no real actions).\n") if ($dryRun != 0);

# Validate aggregation mode possible values
if (not grep (/^$cfgOpts{'aggregation mode'}$/, ('none', 'delta', 'template'))) {
	warnmsg ("Aggregation mode isn't correct!\n");
}

$cfgOpts{'aggregation directory'} = dirConv($cfgOpts{'aggregation directory'});
$cfgOpts{'aggregation virtual directory'} = dirConv($cfgOpts{'aggregation virtual directory'});

fatalmsg ("Current or multilevel directory isn't possible now, sorry. Check aggregation arguments.\n"), die
    if ($cfgOpts{'aggregation mode'} ne "none" and
	(dirValidator($cfgOpts{'aggregation directory'}) == 0 or
	 dirValidator($cfgOpts{'aggregation virtual directory'}) == 0));

# Calculate ExifTool's verbosity
my $exiftoolVerbose = ($verbose > $maxVerbosity) ? ($verbose - $maxVerbosity) : 0;

# ExifTool object configuration
my $exifTool = new Image::ExifTool;
$exifTool->Options(Binary => 1, Unknown => 1, DateFormat => '%Y%m%d%H%M%S', Verbose => $exiftoolVerbose);

chdir ($workDir) || ( fatalmsg ("Can't enter to $workDir!\n"), die );

if ($subFileSet eq "") {
	# All things in ARGV will be treated as file names to process
	@files = @ARGV;
} else {
	dbgmsg (2, "Reading file names for processing from file: $subFileSet\n");
	@files =  getFileDataLines($subFileSet);
	chomp(@files);
}

# if no file is given
if (scalar(@files) == 0) {
	# opendir(DIR, "./") || ( fatalmsg ("Can't open $workDir!\n"), die );
	# my $file;
	# while ( defined ( $file = readdir DIR )) {
	# 	next if (not -f $file);			# skip absent file or not a file
	# 	push (@files, $file) if (substr($file, length($file) - length($extToProcess)) eq $extToProcess);
	# }
	# closedir(DIR);
	my $fileMask = "*" . $extToProcess;
	@files = grep { -f } glob( $fileMask );
}

# independently of @files initialization doing this
my @filenames;

foreach my $file ( @files ) {
	next if (not -f $file);				# skip absent file or not a file
	next if (grep {/^$file$/} @excludeList);	# skip excluded file
	push (@filenames, $file);
}

# No file to process?
if (scalar(@filenames) == 0) {
	fatalmsg ("No files to process!\n");
	exit 1;
}

# Parse configuration file tag set
foreach my $cKey (keys %cfgOpts) {
	next if ($cKey !~ m/^tag(file)?#\d+#\d+$/);	# skip not a tag or tagfile
	my %tag = strToHash($cfgOpts{$cKey});
	foreach my $key (keys %tag) {
		$tags{$key} = $tag{$key};
		if ($cKey =~ m/^tagfile/) {
			dbgmsg (4, "main(): Read data from '$tags{$key}{value}' for '$key'\n");
			$tags{$key}{value} = getFileData($tags{$key}{value});
		}
	}
}

# Put command line arguments to appropriate tags
$tags{'Comment'} = {value => getFileData($comfile)} if (defined $comfile);
$tags{'UserComment'} = {value => $userComment} if (defined $userComment);

# Merge tags from configuration file with command line arguments
map { $tags{$_} = $tagsFromCli{$_} } keys %tagsFromCli;

# Print parsed tags at debug level
my @dbgTags;
foreach my $key (sort (keys %tags)) {
	my $group = defined $tags{$key}{group} ? $tags{$key}{group} : "";
	my $value = defined $tags{$key}{value} ? $tags{$key}{value} : "";
	push (@dbgTags, "$key [$group] = $value");
}
dbgmsg (4, "Tags:\n", join("\n", @dbgTags), "\n") if (scalar(@dbgTags) > 0);

# Validate angle value
if ((defined $rotateAngle and not grep(/^$rotateAngle$/, keys %rotangles)) or
    (defined $rotateThumbnail and not grep(/^$rotateThumbnail$/, keys %rotangles))) {
	fatalmsg ("Angle should be 90, 180 or 270!\n");
	exit 1;
}

@files = sort @filenames;
dbgmsg (4, "main(): Pushed files(", scalar(@files), "):\n", join("\n", @files), "\n");

# Preparing the variable, which contains the format of the counter output
my $counterSize;

if ($countFF != 0) {
	my $size = length((scalar(@filenames) - 1) * $countStep + $countStart);
	$counterSize = "%." . $size . "d";
	dbgmsg (1, "main(): Counter size: $size (amount files in cache: ", scalar(@filenames), ")\n");
} else {
	$counterSize = "%d";
}

renRotProcess($exifTool, $counterSize);
aggregationProcess($exifTool, $counterSize);

if ($isThereIM) {
	contactSheetGenerator($exifTool);
}

__END__

=head1 NAME

renrot - rename and rotate images according EXIF data

=head1 SYNOPSIS

renrot [OPTIONS] [[B<-->] FILE1 FILE2 ...]

=head1 DESCRIPTION

B<Renrot> is intended to work with a set of files containing EXIF data and
can do two things to them -- rename and rotate. A set of files can be given
either explicitly or using the B<--extension> option, which select the files
with the given suffix. B<Renrot> operates on files in current working
directory, unless given the B<--work-directory> option, which changes this
default.

B<Renrot> renames input files using a flexible name template (which,
among others, uses DateTimeOriginal and FileModifyDate EXIF tags, if they
exist, otherwise names the file according to the current timestamp). Further,
B<renrot> can aggregate files according to the shooting time period or to a
given template.

Additionally, it rotates files and their thumbnails, as per Orientation EXIF
tag. If that tag is absent, the program allows to set rotation parameters
using B<--rotate-angle> and B<--rotate-thumb> command line options. This is
currently implemented only for JPEG format.

The program can also place commentaries into the following locations:

=over

- Commentary tag from file (see B<--comment-file> option)

- UserComment tag from configuration variable (see L</TAGS> section)

=back

Personal details may be specified via XMP tags defined in a configuration
file, see L</TAGS> section.

In addition, B<renrot> can aggregate all files in different directories,
according to a given date/time pattern template, set with B<--aggr-template>.

=head1 OPTIONS

=over

=item B<-c> or B<--config-file> F<FILE>

Path to the configuration file.

=item B<-d> or B<--work-directory> F<DIR>

Define the working directory.

=item B<--exclude> F<FILE>

Specify files to exclude. Wildcards are not allowed. If a set of files is
given, there must be as many occurrences of this option as there are files in
the set.

=item B<--sub-fileset> F<FILE>

Get names of files to operate upon from F<FILE>. The file must contain a
file name per line. This option is useful when you need to process only a
set of X from Y files in the directory. If specified, the rest of files
given in the command line is ignored.

=item B<-e> or B<--extension> I<EXTENSION>

Process the files with given I<EXTENSION> (JPG, jpeg, CRW, crw, etc).
Depending on the operating system, the extension search might or might not be
case-sensitive. 

=item B<-n> or B<--name-template> I<TEMPLATE>

A template to use for creating new file names while renaming. It can also be
defined in the configuration file (variable Name Template). The default is
I<%Y%m%d%H%M%S>. For practical uses, see L</TEMPLATE EXAMPLES> section.

Interpreted sequences are:

=over

B<%%>	a literal %

B<%C>	Numeric part of the original file name. Implemented for the sake
of cameras, that do not supply FileNumber EXIF tag (currently all makes,
except I<Canon>). Such cameras generate file names starting with letters
and ended with digits. No other symbols are allowed in file names, except
C<->, C<.> and C<_>.

B<%c>	Ordinal number of file in the processed file set (see also 
B<--counter-fixed-field> option).

B<%d>	Day of month (01-31).

B<%E>	The value of ExposureTime tag, if defined.

B<%e>	Old file extension

B<%F>	The value of FNumber tag, if defined.

B<%H>	Hour (00-23).

B<%I>	The value of ISO tag, if defined.

B<%i>	FileNumber tag if exists (otherwise, it is replaced by string
C<NA>).

B<%M>	Minute (00-59).

B<%m>	Month (01-12).

B<%n>	Previous filename (the one before B<renrot> started processing).

B<%O>	Base part of the original filename (see B<%o>). In other words, the
first part from the beginning to the last dot character.

B<%o>	The name file had before it was processed by B<renrot> for the
first time. If the file was processed only once, the tag
RenRotFileNameOriginal is set to the original file name.

B<%S>	Second (00-59)

B<%W>	The value of WhiteBalance tag, if defined.

B<%Y>	Year with the century (1900, 1901, and so on)

B<%y>	Year without a century (00..99)

=back

=item B<--no-rename>

Do not rename files (default is to rename them to YYYYmmddHHMMSS.ext)

=item B<--counter-fixed-field>, B<--no-counter-fixed-field>

Set fixed length for file counter, used in file name templates (see B<%c>).
It is enabled by default. Use B<--no-counter-fixed-field> to undo its effect.

=item B<--counter-start> I<NUMBER>

Initial value for the file counter (default is I<1>)

=item B<--counter-step> I<NUMBER>

Step to increment file counter with (default is I<1>)

=item B<-r> or B<--rotate-angle> I<ANGLE>

Define the angle to rotate files and thumbnails. Allowed values for I<ANGLE>
are 90, 180 or 270. It is useful for files not having Orientation tag.

=item B<--rotate-thumb> I<ANGLE>

Rotate only thumbnails. Allowed values for I<ANGLE> are 90, 180 or 270 degrees.
Use if the files which were already rotated, but their thumbnails were not.

=item B<--only-orientation>

Rotate by changing the value of Orientation tag, no real rotation will be
made. The sequence of values to rotate an image from normal (0 degrees) by
90 degrees clockwise is: 0 -> 90 -> 180 -> 270 -> 0. It means. set Orientation
tag to 90cw after the first rotation, and increase that value by 90 each time
the rotation is applied. For 270cw the rotation algorithm uses the reverted
sequence. Rotation by 180cw triggers values in two pairs: 0 <-> 180
and 90 <-> 270. This option cannot be applied to mirror values of Orientation
tag.

=item B<--trim>, B<--no-trim>

Pass the C<-trim> option to L<jpegtran(1)>, to trim if needed. By default,
trimming is enabled. Use B<--no-trim> to disable it.

=item B<--no-rotate>

Do not rotate images (default is to rotate according to EXIF data).

=item B<--mtime>, B<--no-mtime>

Defines whether to set the file's mtime, using DateTimeOriginal tag value.
Use B<--no-mtime> to set it to current time stamp after processing.

=item B<--keywordize>, B<--no-keywordize>

Whether to keywordize. Default is to not. Be careful, since with this option
enabled, the existing keywords are rewriten. The keywords are taken from
F<.keywords> file or file specified with option B<--keywords-file>.

=item B<-k> or B<--keywords-file> F<FILE>

Path to the file with keywords. Its format is a keyword per line. The CR and
LF symbols are removed. Empty (only whitespace) lines are ignored. Any leading
and trailing whitespace is removed. For example, the line C<  _Test_  CRLF> is
read as C<_Test_>.

=item B<--keywords-replace>, B<--no-keywords-replace>

Replace existing Keywords tag list rather than add new values to it. Default
is not to replace.

=item B<--aggr-mode> I<MODE>

Run aggregation process in given I<MODE>. Possible values are: none, delta or
template.

=item B<--aggr-delta> I<NUMBER>

Aggregation time delta, in seconds. Files with DateTimeOriginal and ones of
the previous file delta, greater than B<--aggr-delta> are placed in the
directory, with the name constructed by concatenating the value of the
B<--aggr-directory> option and the directory name counter.

=item B<--aggr-directory> F<DIR>

Aggregation directory name prefix (default is I<Images>)

=item B<-a> or B<--aggr-template> I<TEMPLATE>

File name template to use for file aggregation. Images are aggregated by
date/time patterns. You may use combination of B<%d>, B<%H>, B<%M>, B<%m>,
B<%S>, B<%Y>, and B<%y> meta-characters. The template can also be defined
in the configuration file (see Aggregation Template variable). The default
is I<%Y%m%d>. For the detailed description, refer to B<--name-template>
option. For practical uses, see L</TEMPLATE EXAMPLES> section.

=item B<--aggr-virtual>, B<--no-aggr-virtual>

Defines virtualization for existent aggregation modes. If set, resulting files
are placed into the directory given by the command line option
B<--aggr-virtual-directory> or configuration file option B<aggregation virtual
directory> then any changes required by the current aggregation mode are
applied. The main effect of B<--aggr-virtual> is that any files to be
aggregated remain untouched in their places, and symlinks pointing to them
are stored in the directory tree created. Use B<--no-aggr-virtual> to
prevent virtualization.

=item B<--aggr-virtual-directory> F<DIR>

Store virtual aggregation files in F<DIR>

=item B<--comment-file> F<FILE>

File with commentaries. It is a low priority alias to I<TagFile = Comment: FILE>.

=item B<--user-comment> I<STRING>

A low priority alias to I<--tag UserComment: STRING>

=item B<-t> or B<--tag> I<TAG>

See the section L</TAGS>, for the detailed description

=item B<--no-tags>

No tags will be written. This is the default.

=item B<--use-color>, B<--no-use-color>

Colorize output. This does NOT work under Win32.

=item B<--dry-run>

Do not do anything, only print would have been done.

=item B<--use-ipc>, B<--no-use-ipc>

Rotate thumbnails using pipe, rather than files. This does NOT work under Win32.

=item B<-v>

Increase debugging level by 1. Debugging levels from 1 to 4 are internal
levels, the levels from 5 till 9 are equivalent to levels 1-5 levels ExifTool
with the maximum verbosity for B<renrot>.

=item B<-?> or B<--help>

Display short usage summary and exit.

=item B<--version>

Output version information and exit.

=back

=head1 B<CONTACT SHEET GENERATOR>

=item B<--contact-sheet>

Create the contact sheet. Currently it works with ThumbnailImage EXIFs
and the files defined as thumbnails (see the option B<--contact-sheet-thm>,
below)

=item B<--contact-sheet-file> F<FILE>

Base file name for montage files.

=item B<--contact-sheet-dir> F<DIR>

Temporary directory for montage (created in the begining and deleted at the
end of the process)

=item B<--contact-sheet-thm>

Files for the montage are already thumbnails

=over

Options bellow are native ImageMagic montage options
look ImageMagick documentation for montage options:
I<montage --help> and I<http://www.imagemagick.org/>

Note please, for I<COLOR> use RGB triplets only
like I<000> for the I<black> or I<F00> for the I<red>.

=back

=item B<--contact-sheet-tile> I<GEOMETRY>

Tile MxN (IM: -tile)

=item B<--contact-sheet-title> I<STRING>

Set the title of the contact sheet (IM: -title).

=item B<--contact-sheet-bg> I<COLOR>

Background color (IM: -background).

=item B<--contact-sheet-bd> I<COLOR>

Border color (IM: -bordercolor).

=item B<--contact-sheet-mt> I<COLOR>

Frame color (IM: -mattecolor).

=item B<--contact-sheet-fn> I<STRING>

Render text with this font (IM: -font).

=item B<--contact-sheet-fl> I<COLOR>

Color to fill the text (IM: -fill).

=item B<--contact-sheet-lb> I<STRING>

Assign a label to an image (IM: -label).

=item B<--contact-sheet-fr> I<GEOMETRY>

Surround image with an ornamental border in N pixels (IM: -frame).

=item B<--contact-sheet-pntsz> I<NUMBER>

Font point size (IM: -pointsize).

=item B<--contact-sheet-shadow>

Set the shadow beneath a tile to simulate depth (IM: -shadow).

=over

=head1 B<TEMPLATE EXAMPLES>

The name template C<01.%c.%Y%m%d%H%M%S.%i.%E%F%W%I> (where I<F> stays for
FNumber, I<E> for ExposureTime, I<I> for ISO and I<W> for WhiteBalance)
can produce the following names:

=over

01.0021.20030414103656.NA.E1by40F2.8WAutoI160.jpg

01.0024.20040131230857.100-0078.E1by320F2.8WAutoI50.jpg

01.0022.20000820222108.NA.jpg

=back

The aggregation template C<%Y%m%d> produces the following aggregation:

these three files

=over

01.11.20030414103656.NA.jpg

01.12.20030414103813.NA.jpg

01.13.20030414103959.NA.jpg

=back

will be stored in the directory I<20030414>, and

=over

01.14.20040131130857.100-0078.jpg

01.15.20040131131857.100-0079.jpg

01.16.20040131133019.100-0080.jpg

01.17.20040131135857.100-0083.jpg

=back

will be stored in the directory F<20040131>.

=head1 CONFIG

A configuration file can be used to set some variables. B<Renrot> looks for
its configuration file, named F<renrot.conf>, in system configuration
directories F</etc/renrot> and </usr/local/etc/renrot>, and in subdirectory
F<.renrot>. of the current user home directory. An alternate configuration
file can also be explicitly given using the B<--config-file> option. 

The configuration file consists of a set of case-insensive keywords and their
values separated by equal sign. Each such keyword/value pair occupies a
separate line. Boolean variables can have one of the following values: 0, No,
False, Off for false, and 1, Yes, True, On for true.

The variables defined for use in configuration file are:

=over

=item B<mtime>

Set to C<Yes> for synchronize mtime with tags, otherwise set it to C<No>.

=item B<name template>

File name template (see B<--name-template>, for the description).

=item B<trim>

Set to C<Yes> to trim rotated images when using L<jpegtran(1)>.

=item B<aggregation mode>

Aggregation mode, possible values are: none, delta or template.

=item B<aggregation template>

Aggregation template, which defines the file aggregation (see
B<--aggr-template>, for the description).

=item B<aggregation virtual>

Defines virtualization for the existing aggregation modes
(see the B<--aggr-virtual> option).

=item B<aggregation virtual directory>

Defines a directory for virtual aggregation (see the
B<--aggr-virtual-directory> option>).

=item B<Tag>, B<TagFile>

Refer to the section L</TAGS>, for the detailed description

=item B<include>

Include the named file.

=back

=head1 TAGS

A I<TAG> is defined by the following combination: I<TagName [Group]: 'value'>.
The defined tags are selected to be set and writen to the EXIF tree using
the command line option B<--tag> and/or configuration file options B<Tag>.

The syntax of the command line option B<--tag> is:

=over

B<--tag> I<TagName [Group]: 'value'>

=back

The syntax of the configuration file option B<Tag>:

=over

B<Tag> = I<TagName [Group]: 'value'>

=back

The parameters I<TagName> and I<Group> are passed to ExifTool as is. The
name of the group must be enclosed in square brackets. Its I<value> (after
the semicolon) can be enclosed in single quotes.

The TagFile keyword allows to set multi-line tags from a file. Its syntax is:

=over

B<TagFile> = I<TagName [Group]:> F<FILE>

=back

The following table summarizes the tags that can be used with the B<--tag>
option and B<Tag> keyword:

=over

=item B<Copyright>

Copyright notes.

=item B<Comment>

General comment.

=item B<UserComment>

Anything you would like to put as a comment.

=item B<CreatorContactInfoCiAdrCity>

A city tag.

=item B<CreatorContactInfoCiAdrCtry>

A country tag.

=item B<CreatorContactInfoCiAdrExtadr>

Extended address (usually includes street and apartment number).

=item B<CreatorContactInfoCiAdrPcode>

Zip code.

=item B<CreatorContactInfoCiAdrRegion>

Region.

=item B<CreatorContactInfoCiEmailWork>

Email.

=item B<CreatorContactInfoCiTelWork>

Phone number.

=item B<CreatorContactInfoCiUrlWork>

URL.

=back

Additionally, you can add any known tag here, using B<Tag> or
B<TagFile> options as described above.

=head1 FILES

The configuration file is searched in the following locations
(in the order of their appearence):

=over

=item B<~/.renrot/renrot.conf>

=item B</usr/local/etc/renrot/renrot.conf>

=item B</etc/renrot/renrot.conf>

=back

=head1 BUGS

If you found some bug or have some nice propositions, you are welcome.
Additionally, please, read the section RESTRICTIONS in file README.

It seems that on FreeBSD 6, Perl versions 5.8.7 and 5.8.8, exhibit a bug
that causes B<renrot> to crash.

If the sizes of files to be processed sum up to a value greater than your RAM
amount, B<renrot> aborts with the error message:

=over

Out of memory during "large" request for XXXX bytes ...

=back

This, however, does not happen with Perl v.5.6.x

=head1 AUTHORS

Copyright 2005-2007, Zeus Panchenko, Andy Shevchenko.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,L<exiftool(1)>,L<jpegtran(1)>,L<Image::Magick(3pm)|Image::Magick>

=cut
