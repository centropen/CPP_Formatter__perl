use strict;
use warnings;
use Carp;
use Data::Dumper;
use File::Basename;

use lib '.';
use RegExpFileSearcher;
use PerlMassFileTranslator;


## MAIN
#$srcPath  =~ s/\\/\//g;
my $ttt = 'c:/DEVEL/pserver/windekis/Windekis/BBB/windekis/windekis/source/test_perlmassformatter/db.cpp';
#$ttt = 'c:/DEVEL/pserver/WINDEKIS/windekis/Genix/ApWare32/ProzessMgr/Source/DbDescProzessMgrStandalone.cpp';
#cut to 4 parts

if ($ttt =~ m/(^..\/(\w*\/)+pserver\/windekis\/windekis)(.*)/i) 
#m/((^.*windekis\/windekis)(.*))/i) #((windekis\/windekis\/)|(source))(.*))?i) #.*((windekis\/){2}\/source).*$?i) 
{
	print "1-> $1\n"; #A
	print "3-> $3\n"; #B
	
	my $A = $1; my $B = $3;
	do {$A =~ s/\//|/g; } if $A;
	
	my $AB = $A.$B;
	print $AB;
}


exit;

=comment
#TODO implement also in main script PerlMassFormatter.pl
# ![1]
sub reformat {
	my ($regExpFiles, $tmpPrefixFileName, $removeEmptyLines, $writeSignature) = @_;
	$removeEmptyLines = 1 if !defined($removeEmptyLines);
	
	croak "Cannot call reformat, no reference to regExpFileSearcher, call setInput() first!" 
			if !defined($regExpFiles);
		
	foreach my $fileName(@$regExpFiles) {	
		my $translObj = new PerlMassFileTranslator($fileName);
		$translObj->setTmpOutputFileName($tmpPrefixFileName);
		print "Tmp file set to: ".$translObj->getTmpOutputFileName()."\n";
		print "Src File set to: ".$translObj->getFileName()."\n";
		
		my $tmpFileName = $translObj->getTmpOutputFileName();
		my $cntSignatures = $translObj->removeSignature(\$tmpFileName);
		print "Removed old signature from ".basename($tmpFileName).", removed: $cntSignatures lines.\n" if $cntSignatures gt 0;

		$translObj->translate($writeSignature);
		
		my $emptyLines = $translObj->removeEmptyLines(\$tmpFileName);
		print "Removed $emptyLines empty lines from ".basename($tmpFileName)."\n";
		#TODO autoremove
	}
}

#TODO implement also in main script PerlMassFormatter.pl
# ![2] arg1 = plus files
#      arg2 = minus files
# returns maps
sub calculateSize {
	my ($ref_origFiles, $prefix) = @_;
	my $sumPlusSize = -1 if !defined($ref_origFiles);
	my %sizes;
	# do not burn down if not handled properly, it's only reporting
	do {
		my $orig_size = 0;
		my $new_size = 0;
		foreach my $file(@$ref_origFiles) {
			# get the filename of the new file
			my $new_file = PerlMassFileTranslator::getPrefixedFileName(\$file, $prefix);
			my $tmp = PerlMassFileTranslator::getFileSize(\$file);
			$orig_size = $orig_size + $tmp;
			
			$tmp = 0;
			$tmp = PerlMassFileTranslator::getFileSize(\$new_file);
			$new_size = $new_size + $tmp;
		}
		$sizes{original_sum_size} = $orig_size;
		$sizes{new_sum_size} = $new_size;
		$sizes{diference_size} = $orig_size-$new_size;
		
	} if defined($ref_origFiles);
	return %sizes;
}


#main
my $searchObj = PerlMassFileTranslator::setInput($folder);
my $ar = $searchObj->getFiles();
######reformat($ar,'000', 1, 0);
#![2] call size for html


my $posArray = $searchObj->getFiles();
my %sizes_h = calculateSize($posArray, '000');
print Dumper \%sizes_h;




















