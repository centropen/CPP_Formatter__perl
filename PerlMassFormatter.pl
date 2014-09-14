#!/usr/bin/perl
use strict;
use warnings;
use boolean ':all';
use Fcntl ':flock';    				# lock files when writing
use Carp;              				# use croak instead of die
use Data::Dumper;
use File::Spec;        				# file path
use File::Basename qw/ dirname basename /;
use FindBin qw( $RealBin );
use Path::Class;       				# recursive file search -> out
use File::Find::Rule;
use POSIX;
use Getopt::Long;					# for command line args
use encoding "utf8";
############################################################################################
# GLOBAL VARS:
my $VERSION = "0.01";
my $srcPath	= '';    				# the topmost windekis folder path with sources
my $htmlfileName = "CPP_Formatter.html";
my $plusRegExp = '^DbDesc.*\.cpp';
my $minusRegExp = '.*Zusatz.*';
my $chosenPrefix = '000_';
my $renameOnFinish = 0;				# by default off.
my $filePath = '';					# the second possiblity to enter only one file instead of $srcPath
my $signature = 0;
my $compress = 1;					# remove empty lines from file
my $printHTML = 1;					# print HTML report after finishing
my $stripJSONPath = 1;				# remove windkis duplicity in a path

#!/usr/bin/perl
use lib '.';
use PerlMassFileTranslator;
use BinTreePath2JSON;
use HTMLBuilder;


sub usage()
{
	printf("%85s  %-36s\n","usage: program [-s|-src|-windekis WINDEKIS SRC PATH]", "<Mandatory>");
	printf("%85s  %-36s\n","usage: program [-f|-file PATH TO FILE]", "<Mandatory>");
	printf("%85s  %-36s\n","usage: program [-ra|-renall]", "<Mandatory>");
	printf("%85s  %-36s\n","usage: program [-p|-prefix PREFIX OF FILE(s) TO BE CREATED]", "<Optional: Default - $chosenPrefix>");
	printf("%85s  %-36s\n","usage: program [-plus]",  "<Optional: Default - $plusRegExp>");
	printf("%85s  %-36s\n","usage: program [-minus]", "<Optional: Default - $minusRegExp>");
	printf("%85s  %-36s\n","usage: program [-rename]", "<Optional: Default - $renameOnFinish>");
	printf("%85s  %-36s\n","usage: program [-sig|-signature WRITE SIGNATURE TO A NEW CREATED FILE?]", "<Optional: Default - $signature>");
	printf("%85s  %-36s\n","usage: program [-comp|-compress REMOVE EMPTY LINES FROM FILES]", "<Optional: Default - $compress>");
	printf("%85s  %-36s\n","usage: program [-what]", "<Optional>");
	printf("%85s  %-36s\n","usage: program [-h|-help|?] help ]", "<HELP>");
	printf("%121s\n",'*'x 121);
	printf("%-7s","Example:\n");
	printf("%-7s%-47s%-85s\n",'(1)',basename($0)." -src C:/pserver/windekis", " -> Reformat all files recursive with the new prefixed name.");
	printf("%-7s%-47s%-85s\n",'(2)',basename($0)." -src C:/pserver/windekis -r=1", " -> As previous but rename all files to the original names.");
	printf("%-7s%-47s%-80s\n",'(3)',basename($0)." -src C:/pserver/windekis -comp=0 -sig=1", " -> Reformat all files, don't compress them;");
	printf("%-7s%-47s%-80s\n",'',"", " -> and write down your signature. By default off for saving the space.");
	printf("%-7s%-47s%-80s\n",'(4)',basename($0)." -src C:/pserver/windekis -ra -p tmp_", " -> Reformat all files recursive with the new prefixed name.");
	exit;
}


sub renameAll()
{
	croak "No Source defined, please for renaming files as input parameter enter -src PATH TO FOLDER!" if !defined($srcPath);
	my $searchObj = PerlMassFileTranslator::setInput($srcPath, $plusRegExp, $minusRegExp);
	my $ar = $searchObj->getFiles();
	renamePrefixedFilesToLiveFiles($ar);
	exit;
}

sub what()
{
	printf("%-30s\n", '-' x 26);
	printf("%-30s\n", "By default set parameters:");
	printf("%-30s\n", '-' x 26);
	printf("%-7s%-30s%-30s\n", "(1)", "Version:", $VERSION);
	printf("%-7s%-30s%-30s\n", "(2)", "Application name:", basename($0));
	printf("%-7s%-30s%-30s\n", "(3)", "Chosen Prefix for files:", $chosenPrefix);
	printf("%-7s%-30s%-30s\n", "(4)", "+ regular expression: ", $plusRegExp);
	printf("%-7s%-30s%-30s\n", "(5)", "- regular expression:", $minusRegExp);
	printf("%-7s%-30s%-30s\n", "(6)", "Files automat. renamed:", ($renameOnFinish ? 'YES' : 'NO') );
	printf("%-7s%-30s%-30s\n", "(7)", "Write Signature:", ($signature ? 'YES' : 'NO') );
	printf("%-7s%-30s%-30s\n", "(8)", "Compress:", ($compress ? 'YES' : 'NO') );
	printf("%-7s%-30s%-70s\n", "(9)", "HTML Report Name:", $htmlfileName);
	
	exit;
}

#![0]
GetOptions(
	's|src|windekis=s' 	=> \$srcPath,
	'f|file=s'			=> \$filePath,
	'ra|renall'			=> \&renameAll,
	'p|prefix=s'		=> \$chosenPrefix,
	'plus=s'			=> \$plusRegExp,
	'minus=s'			=> \$minusRegExp,
	'rename=i'			=> \$renameOnFinish,
	'sig|signature=i'	=> \$signature,
	'comp|compress=i'	=> \$compress,
	'what'				=> \&what,
	'h|help|?'			=> \&usage
) or usage();

print ("----------------------------------------------------------------------.\n");
print ("------------------------INPUT IS SET TO: -----------------------------.\n");
print ("----------------------------------------------------------------------.\n");

$srcPath  =~ s/\\/\//g;
$filePath =~ s/\\/\//g;

# ![1]
############################################################################################
# reformat -> the core aligns the columns
############################################################################################
sub reformat {
	my ($regExpFiles, $tmpPrefixFileName, $removeEmptyLines, $writeSignature) = @_;
	$removeEmptyLines = 1 if !defined($removeEmptyLines);
	
	croak "Cannot call reformat, no reference to regExpFileSearcher, call setInput() first!" 
			if !defined($regExpFiles);
		
	foreach my $fileName(@$regExpFiles) {	
		my $translObj = new PerlMassFileTranslator($fileName);
		$translObj->setTmpOutputFileName($tmpPrefixFileName);
		
		my $tmpFileName = $translObj->getTmpOutputFileName();
		my $cntSignatures = $translObj->removeSignature(\$tmpFileName);
		print "Removed old signature from ".basename($tmpFileName).", removed: $cntSignatures lines.\n" if $cntSignatures gt 0;

		$translObj->translate($writeSignature);
		
		if ($removeEmptyLines eq 1) {
			my $emptyLines = $translObj->removeEmptyLines(\$tmpFileName);
		}
	}
}
# ![2]
############################################################################################
# calculateSize -> for html reports
############################################################################################
# returns maps -> check OK
sub calculateSize {
	my $ref_origFiles = shift;
	my $sumPlusSize = -1 if !defined($ref_origFiles);
	
	my $getForNewFiles = (defined($chosenPrefix) ? 1 : 0);
	my %sizes;
	# do not burn down if not handled properly, it's only reporting
	do {
		my $orig_size = 0;
		my $new_size = 0;
		foreach my $file(@$ref_origFiles) {
			# get the filename of the new file
			my $new_file = PerlMassFileTranslator::getPrefixedFileName(\$file, $chosenPrefix);
			print "newfile: $new_file\n";
			my $tmp = PerlMassFileTranslator::getFileSize(\$file);
			print "origfile: $tmp\n";
			$orig_size = $orig_size + $tmp;
			
			do {
				$tmp = 0;
				$tmp = PerlMassFileTranslator::getFileSize(\$new_file);
				$new_size = $new_size + $tmp;
			} if ($getForNewFiles==1);
		}
		$sizes{original_sum_size} = $orig_size;
		$sizes{new_sum_size} = $new_size;
		$sizes{diference_size} = $orig_size-$new_size;
		
	} if defined($ref_origFiles);
	$sizes{files_cnt} = scalar(@$ref_origFiles);
	return %sizes;
}

# ![3]
############################################################################################
# generateHTMLReport returns the name of generated json file
############################################################################################
sub generateJSONData {
	my $refFilesList = shift;
	
	my $root;
	croak "Array for input wasn't specified." if (!$refFilesList);
	do {
		foreach my $value(@$refFilesList) {
			if ($value =~ m/(^..\/(\w*\/)+pserver\/windekis\/windekis)(.*)/i) {
				my $A = $1; my $B = $3;
				do {$A =~ s/\//|/g; } if $A;
				
				$value = $A.$B;
				$root = $A if !$root;
			}
		}	
	} if ($stripJSONPath eq 1);
	
	my $binTreeObj = new BinTreePath2JSON();
	croak "Error in generateHTMLReport, no object found $!" if !defined($binTreeObj);	
	
	$binTreeObj->setPathList($refFilesList);
	if ($binTreeObj->getError() != 0) {
		croak "There is an error - $binTreeObj->getErrorText()";
	}
	$binTreeObj->setFile();
	my $jsonFile = $binTreeObj->getFile();
	print "INFO: File will be created as : $jsonFile.\n";
	
	my $error = $binTreeObj->save2JSON();
	print "There was an error on JSON generating, please check again your call.\n" if $error ne 0;
	print "<$jsonFile> was successfully generated.\n" if $error eq 0;
	
	print "Number of trapped files: ".$binTreeObj->count()."\n";
	
	return basename $jsonFile;
}

# ![4]
############################################################################################
# generateHTMLReport returns the name of generated json file
############################################################################################
sub generateOpenWebSite {
	my ($origsize, $newsize, $difsize, $cnt, $jsonFileName) = @_;
	my $websitepath = File::Spec->catfile( dirname($0), $htmlfileName);
	print "websitepath: << "; print $websitepath; print " >>\n";
	my $tmplpath = File::Spec->catfile( dirname($0), '\web\CPPFormatterReport.tmpl');

	my $datetime = POSIX::strftime("%d.%m.%Y at %H:%M:%S", localtime);
	
	my $spath = ($srcPath eq '') ? $filePath : $srcPath;
		
	HTMLBuilder::GenerateWebSite($tmplpath, $websitepath, $spath, $plusRegExp, $minusRegExp,
								 $chosenPrefix, $cnt, $origsize, $newsize, $difsize,
								 basename($0), Win32::LoginName, $VERSION, $jsonFileName,
								 $datetime);
		
	my @command = ('start', $htmlfileName);
	system(@command);						 							
}

# ![5]
############################################################################################
# generateHTMLReport returns the name of generated json file
############################################################################################
sub renamePrefixedFilesToLiveFiles {
	my $refList = shift;
	croak "No List of Files defined! Please Create a list of files first!" if !defined($refList);
	print scalar(@$refList);
	print " Files starting with prefix: $chosenPrefix will be renamed\n";
	foreach my $file(@$refList) {
		print "file: $file -> $file\n";
		my $name = basename($file);
		my $dir = dirname($file);
		my $oldfilename = $chosenPrefix.$name;
		my $oldname = File::Spec->catfile( $dir, $oldfilename);
		rename $oldname, $file or die "Can't rename $oldname to $file: $!";
		print "file was renamed from $oldname\n";
	}
	print "All Files have been successfully renamed to the original name.\n";
}


############################################################################################
# MAIN #####################################################################################
############################################################################################
	my $ar; 
	if ($filePath ne '') {
		$printHTML = 0;
		my $searchObj = PerlMassFileTranslator::setInput($filePath, $plusRegExp, $minusRegExp);
		my @fileArray;
		push @fileArray, $filePath;
		$ar = \@fileArray;
		
	} elsif ($srcPath ne '') {
		#cut the path to 2 parts
		my $searchObj = PerlMassFileTranslator::setInput($srcPath);
		$ar = $searchObj->getFiles();
	}
	else {
		print "Error occurred. There was no input entered; please enter source folder or path to one file!\n";
		exit;
	}
	
	reformat($ar,$chosenPrefix, $compress, $signature);
	
	do {
		# call size for html
		my %sizes_h = calculateSize($ar);
		my $jsonFile = generateJSONData($ar);
		print "jsonfilename is: $jsonFile\n";
	
		my $prettyText_orig_sum_size = PerlMassFileTranslator::getSizeAsText($sizes_h{original_sum_size}) || 0;
		my $prettyText_new_sum_size = PerlMassFileTranslator::getSizeAsText($sizes_h{new_sum_size}) || 0;
		my $prettyText_diff_sum_size = PerlMassFileTranslator::getSizeAsText($sizes_h{diference_size}) || 0;

		generateOpenWebSite($prettyText_orig_sum_size, $prettyText_new_sum_size, $prettyText_diff_sum_size, 
							$sizes_h{files_cnt},  
							$jsonFile);
	} if ($printHTML eq 1);
	if ($renameOnFinish == 1) {
		renamePrefixedFilesToLiveFiles($ar);
	}
	
	print "\nEnd of operations.\n";
	print ("----------------------------------------------------------------------.\n");
	print ("------------------------THANK YOU and BYE-----------------------------.\n");
	print ("----------------------------------------------------------------------.\n");
	
	exit;
