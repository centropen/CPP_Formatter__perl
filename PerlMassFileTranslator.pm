#!/usr/bin/perl 
package PerlMassFileTranslator;

use warnings;
use Fcntl ':flock';		# lock files when writing
use Carp;				# use croak instead of die
use POSIX;				# for timestamp
use Readonly;			# for constant
use Tie::File;			# feed file in array
use Data::Dumper;
use File::Basename;
use Text::Trim;

#own library for public functions
use RegExpFileSearcher;

=head1 NAME
PerlMassFileTranslator - package with public section, takes path, filename pattern as regular expression
						 and finds all files in down-falling mode.
						 <optional> There can be defined negative expression for matching all these files
						 <optional> Depth for looking for.
=head1 VERSION
Version 0.0.1
=cut
=head1 PUBLIC SECTION
=cut

=head2 PUBLIC METHODS
=head3 setInput
	ref RegExpFileSearcher = 
	setInput(folderPath, regExpFileName='^DbDesc.*', negativeRegExpFileName='.*Zusatz$', depth=20)
=cut

=head2 PUBLIC SECTION
=head3
ret delSpaces(arg) - remove empty spaces from the beginning, end and inner text returning result. 
=cut
sub delSpaces {
	my $text = shift;
	$text =~ s/\s+//g;
	$text =~ s/^\s//;
	$text =~ s/\s$//;
	return $text;
}

sub delSpacesBE {
	my $text = shift;
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	
	my @values = split(',', $text);
	my $values_ref = \@values;
  	for (my $i = 0; $i <= $#$values_ref; $i++) {
   	 	$values_ref->[$i] =~ s/^\s+//;
		$values_ref->[$i] =~ s/\s+$//;	
  	}
  	
  	return join(',',@values);
}

=head3
ret getFileSizeText(ref filename) - returns size of file in bytes as text
=cut
sub getFileSizeText {
	my $reffilename = shift;
	croak "No file specified!" if !$reffilename;
	my $size = -s $$reffilename;
	# format it to ***.***.***
	$size = reverse $size;
	$size =~ s/\d{3}(?=\d)/$&./g;
	$size = reverse $size;
	return "$size Bytes";
}

sub getFileSize {
	my $reffilename = shift;
	croak "No file specified!" if !$reffilename;
	return -s $$reffilename;
}

sub getSizeAsText {
	my $size = shift;
	croak "No size in argument!" if !defined($size);
	$size = reverse $size;
	$size =~ s/\d{3}(?=\d)/$&./g;
	$size = reverse $size;
	return "$size Bytes";
}

sub getStrippedPathStart {
	my ($path, $separator) = @_;
	$path = 'root' if !defined($path);
	$separator = '/' if !defined($separator);
	if ($path =~ m/(\w?\W?$separator?(\w*$separator){1,}?(windekis$separator){1,2})(.*$)/i) {
		return $1;
	}
}

sub getStrippedPathLast {
	my ($path, $prefix2beRemoved, $separator) = @_;
	$separator = '/' if !defined($separator);
	$prefix2beRemoved = '' if !defined($prefix2beRemoved);
	if ($path =~ m/$prefix2beRemoved?(.*)$/i) {
		return $1;
	} else {
		return $path;
	}
	
}

sub getCopyStrippedMatrixPath {
	my ($refArray, $prefix2beRemoved) = @_;
	my @array;
	croak "no Matrix in argument in a function getCopyStrippedMatrixPath!\n" if !$refArray;
	return @$refArray if !$prefix2beRemoved;
	foreach $path(@$refArray) {
		my $val = getStrippedPathLast($path, $prefix2beRemoved);
		push @array, $val;
	}
	return @array;	
}

=head3
ret getPrefixedFileName (ref originalFilename, arg prefix = '000_') -
	returns path inc. filename of a new created file
=cut
sub getPrefixedFileName {
	my ($file, $prefix) = @_;
	croak "Mandatory filename not given as argument. Please specify the filename inc. path!" 
			if !defined($file);
	$prefix = (!defined($prefix) ? '000_' : $prefix);
			
	my $prefixedFileName = $prefix.basename($$file);
	return dirname($$file).'/'.$prefixedFileName;
}

=head3 LOCAL CONSTANTS
DELIMITER 					','
RIGHT_CURLY_BRACKET 		"}"
LEFT_CURLY_BRACKET 			"{"
DEFAULT_SPACE				30
=cut
use constant DELIMITER => ',';
use constant RIGHT_CURLY_BRACKET => '}';
use constant LEFT_CURLY_BRACKET => '{';
use constant DEFAULT_SPACE => 30;



sub setInput {
	my($folderPath, $regExpFileName, $negregExpFileName, $depth) = @_;
	
	my $regObj = new RegExpFileSearcher({folderPath => $folderPath}, 
										{regExpFileName => $regExpFileName},
										{negregExpFileName => $negregExpFileName});

	print "Set parameters are: \n";
	print "<folder>: ".$regObj->getFolderPath();
	print "\n<+regexp>: ".$regObj->getRegExpression4FileName();
	print "\n<-regexp>: ".$regObj->getNegRegExpression4FileName();
	print "\n<depth>: ";
	
	my @array = $regObj->searchForFiles($depth);
	return $regObj;	
}

#END OF PUBLICSECTION

use constant SIGTOKEN => '///# ';

sub new
{
	my $class = $_[0];
	my $self = {
		_fileName 			=>  $_[1],
		_tmpFileName 		=>  $_[2],
		_fileHandle,
		_tmpFileHandle,
		_outFormattedFiles 	=> [],		
		formattingOptions 	=> []
	};
	bless $self, $class;
	
	$self->initialize($self);
	return $self;
}


sub getMaxLengthOfColumnInHash
{
	my $self = shift;
	my %maxColHash;
	croak "No input file defined. Work will be terminated!" if !defined($self->{_fileName});
	open INFILE, '<', $self->{_fileName} or 
		croak "cannot open file for reading of $self->{_fileName}, $OS_ERROR.\n";
		
	foreach my $line(<INFILE>) {
		if ($line =~ m/^\s*{(.*)}\s*,\s*/ ) { # match only the inner text without brackets			
			my $val = delSpacesBE($1);
			my @values = split(DELIMITER, $val);
			for (my $iter = 0; $iter < scalar(@values); ++$iter) {
				my $lg = length $values[$iter];
				$maxColHash{$iter} = 0 if !defined($maxColHash{$iter});
				do { 
					$maxColHash{$iter} = $lg; 
				} if ($lg > $maxColHash{$iter});
			}
		}
	}		
	close INFILE or croak "Unable to close $self->{_fileName}, $!.\n";


	$self->{formattingOptions} = [];
	
	foreach (sort { $a <=> $b } keys(%maxColHash) )
	{
		push $self->{formattingOptions}, -($maxColHash{$_}+2);
	}
	
}

sub initialize
{
	#initialize the first three columns
	my ($self) = @_;
	$self->getMaxLengthOfColumnInHash($self);
=comment
	push $self->{formattingOptions}, -45;
	push $self->{formattingOptions}, -45;
	push $self->{formattingOptions}, -60;
	push $self->{formattingOptions}, -25;
	push $self->{formattingOptions}, -25;	
	push $self->{formattingOptions}, -60;
	push $self->{formattingOptions}, -45;
	push $self->{formattingOptions}, -45;
	push $self->{formattingOptions}, -25;
=cut
}
## destructor
sub DESTROY {
	my ( $self ) = @_;
	#close file handler
	if (defined($self->{_fileHandle}) and defined($self->{_tmpFileHandle})) {
		if (tell($self->{_fileHandle}) != -1) 
		{ close $self->{_fileHandle} or croak "Unable to close $self->{_fileName}, $OS_ERROR!"; }
		print "$self->{_fileName} has been closed.\n";
		
		if (tell($self->{_tmpFileHandle}) != -1)
		{ close $self->{_tmpFileHandle} or croak "Unable to close $self->{_tmpFileName}, $OS_ERROR!"; }
		print "$self->{_tmpFileName} has been closed.\n"; 
	}
}
## setters & getters
# ![0]
sub setTmpOutputFileName {
	my ( $self, $tmpFileName ) = @_; 
	do { $tmpFileName = defined($tmpFileName) ? 
		$tmpFileName.basename($self->{_fileName}) :
						 "000_".basename($self->{_fileName});
	};	
	$self->{_tmpFileName} = dirname($self->{_fileName}) ? dirname($self->{_fileName}).'/'.$tmpFileName : $tmpFileName; 
	return $self->{_tmpFileName};
}

# ![1]
sub getTmpOutputFileName {
	my( $self ) = @_;
	return $self->{_tmpFileName} if defined($self->{_tmpFileName});
}

sub getFileName {
	my ($self) = @_;
	return $self->{_fileName} if defined($self->{_fileName});
}

# ![2]
sub openFiles {
	my ( $self ) = @_;
	#open $self->{_fileHandle}, '<:utf8', $self->{_fileName}
	#	or croak "Error reading file contents of $self->{_fileName} $OS_ERROR.\n ";
	#print "$self->{_fileName} has been opened for reading.\n";

	#open $self->{_tmpFileHandle}, '>:utf8', $self->{_tmpFileName}
	#	or croak "Error opening file error for writing of $self->{_tmpFileName} $OS_ERROR.\n";
	#print "$self->{_tmpFileName} has been opened for writing.\n";	
}

# ![3]
=head2
translate(writeSignature = false);
This method creates second file with reformatted text.
=cut
sub translate {
	my $self = $_[0];
	my $writeSignature = $_[1] || 0;
	 
	open INFILE, '< :encoding(cp1252)', $self->{_fileName} or 
		croak "cannot open file for reading of $self->{_fileName}, $OS_ERROR.\n";
	
	# open tmp file handle 
	open TMPOUTPUT, "> :encoding(cp1252)", $self->{_tmpFileName}
		or croak "Error opening file error for writing of $self->{_tmpFileName} $OS_ERROR.\n";
	
	flock TMPOUTPUT, LOCK_EX;
	
	foreach my $line(<INFILE>) {
		if ($line =~ m/^\s*{(.*)}\s*,\s*/i ) { # match only the inner text without brackets				
			$val = delSpacesBE($1);
			my @values = split(DELIMITER, $val);
			
			if (@values) {				
				# handle first bracket
				#TODO define in variable
				my $iter = 0;
				printf TMPOUTPUT "%3s", LEFT_CURLY_BRACKET;
			
				# handle inner text
				for ($iter = 0; $iter < scalar(@values)-1; ++$iter) {
					#$values[$iter] = delSpacesBE($values[$iter]);
					#print "$values[$iter]\n";
					#not in positions? take the last one and repeat for the rest
					my $actual_position = ( defined($self->{formattingOptions}[$iter]) ? 
													$self->{formattingOptions}[$iter] : 
													$self->{formattingOptions}[$#{$self->{formattingOptions}}] );
					printf TMPOUTPUT "%${actual_position}s", $values[$iter].DELIMITER;
				}
				# handle the last line	
				my $actual_position = ( defined($self->{formattingOptions}[$iter]) ? 
													$self->{formattingOptions}[$iter] : 
													$self->{formattingOptions}[$#{$self->{formattingOptions}}] );											
				printf TMPOUTPUT ("%${actual_position}s", $values[$#values]);
				printf TMPOUTPUT ("%3s\n", RIGHT_CURLY_BRACKET.DELIMITER);
					
				}
			else { # caught empty bracket, handle as common line
				print TMPOUTPUT "$line\n";
			}
		}
		else {
			print TMPOUTPUT "$line\n";
		}
	}
	
	# at the end add the signature
	do { print TMPOUTPUT writeSignature() } if $writeSignature>0;
	
	close INFILE or croak "Unable to close $self->{_fileName}, $!.\n";
	# unlock the IFile
	flock TMPOUTPUT, LOCK_UN;
	
	close TMPOUTPUT or croak "Unable to close $self->{_tmpFileName}, $!.";
	undef $self->{_tmpFileHandle};
	
	print "OK format - $self->{_fileName}.\n";
}

# ![3]
#deprecated
sub translate_D {
	my ( $self ) = @_;

	local ($field, $tabnr, $szdbname, $dbtype, $ctype, $len, $szname, $foreignkey, $flags, $queryflags, $flagsex, $historytabnr);
	
	format ALIGNING_FORMAT = #[12] 50, 40, 35, 30, 30x 
          {   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   },
	$field, $tabnr, $szdbname, $dbtype, $ctype, $len, $szname, $foreignkey, $flags, $queryflags, $flagsex, $historytabnr
.

	
	open INFILE, '<', $self->{_fileName} or 
		croak "cannot open file for reading of $self->{_fileName}, $OS_ERROR.\n";
	
	# open tmp file handle
	open TMPOUTPUT, '>:utf8', $self->{_tmpFileName}
		or croak "Error opening file error for writing of $self->{_tmpFileName} $OS_ERROR.\n";
	
	my $oldhandle = select TMPOUTPUT;
	$~ = "ALIGNING_FORMAT";
	select ($oldhandle);
	
	flock TMPOUTPUT, LOCK_EX;
	
	foreach my $line(<INFILE>) {
		#chomp $line;
		## test comment  starts with ^//s*{.*//s*}//s*,$ ->format it
		if ($line =~ m/^\s*{(.*)}\s*,\s$/i ) { # match only the inner text without brackets
			print "--> { ".$1." } <--\n";
			($field, $tabnr, $szdbname, $dbtype, $ctype, $len, $szname, $foreignkey, $flags, $queryflags, $flagsex, $historytabnr) = split(',', $1);
			# handle empty string
			
			# [1]
			$field = "" if !defined($field);
			trim($field);
			$field = $field.',';
			# [2]
			$tabnr = "" if !defined($tabnr);
			trim($tabnr);
			$tabnr = $tabnr.',';
			# [3]
			$szdbname = "" if !defined($szdbname);
			trim($szdbname);
			$szdbname = $szdbname.',';
			# [4]
			$dbtype = "" if !defined($dbtype);
			trim($dbtype);
			$dbtype = $dbtype.',';
			# [5]
			$ctype = "" if !defined($ctype);
			trim($ctype);
			$ctype = $ctype.',';
			# [6]
			$len = "" if !defined($len);
			trim($len);
			$len = $len.',';
			# [7]
			$szname = "" if !defined($szname);
			trim($szname);
			$szname = $szname.',';
			# [8]
			$foreignkey = "" if !defined($foreignkey);
			trim($foreignkey);
			$foreignkey = $foreignkey.',';
			
			# [10]
			$flags = "" if !defined($flags);
			trim($flags);
			$flags = $flags.',';
			# [11]
			$queryflags = "" if !defined($queryflags);
			trim($queryflags);
			$queryflags = $queryflags.',';
			# [12]
			$flagsex = "" if !defined($flagsex);
			trim($flagsex);
			$flagsex = $flagsex.',';
			# [11]
			if (defined($historytabnr)) {
				trim($historytabnr);
				$historytabnr = $historytabnr.',';
			} else { $historytabnr = ""; }
			
			write(TMPOUTPUT);
			
		} else # dont format it
		{
			print TMPOUTPUT "$line\n";
		}
	}
	
	# at the end add the signature
	print TMPOUTPUT writeSignature();
	
	close INFILE or croak "Unable to close $self->{_fileName}, $OS_ERROR.\n";
	# unlock the IFile
	flock TMPOUTPUT, LOCK_UN;
	
	close TMPOUTPUT or croak "Unable to close $self->{_tmpFileName}, $OS_ERROR.";
	undef $self->{_tmpFileHandle};
	
	# store into array of edited files
	push($self->{_outFormattedFiles}, $self->{_fileName});
	print "Edited $self->{_fileName}.\n";
	
}

# ![4]
sub writeSignature {
	my ( $self ) = @_;
	my $datetime  = POSIX::strftime("%d-%m-%Y at %H:%M:%S", localtime);
	my $userName = Win32::LoginName;
	my $commentLine = SIGTOKEN;
	$commentLine = $commentLine.'-'x 478;
	$commentLine = $commentLine."\n"; 
	$commentLine = $commentLine.SIGTOKEN. "Auto-reformatted by $0\n";
	$commentLine = $commentLine.SIGTOKEN. "Started by $userName\n";
	$commentLine = $commentLine.SIGTOKEN. "Launched at $datetime\n";
	$commentLine = $commentLine.SIGTOKEN ;
	$commentLine = $commentLine.'-'x 478;
	return $commentLine;
}

# ![5]
sub removeSignature {
	my ( $self, $file ) = @_;
	$file = \$self->{_fileName} if !defined($file);
		
	tie my @lines, 'Tie::File', $$file or die "Couldn't open file $file -> $!";

	my $wholeFileInLines = scalar(@lines);
	my $pattern = \SIGTOKEN;
	@lines = grep !/$$pattern/, @lines;
	my $cntOfDeletedLines = $wholeFileInLines - scalar(@lines);

	untie @lines or die "$!";
	
	return $cntOfDeletedLines;
}

sub removeEmptyLines {
	my ( $self, $file ) = @_;
	$file = \$self->{_fileName} if !defined($file);
	
	tie my @lines, 'Tie::File', $$file or die "Couldn't open file $file -> $!";
	my $wholeFileInLines = scalar(@lines);
	my $pattern = '^\s*$';
	@lines = grep !/$pattern/, @lines;
	my $cntOfDeletedLines = $wholeFileInLines - scalar(@lines);
	
	@lines = grep !/$pattern/, @lines;
	
	return $cntOfDeletedLines;
}

# ![6]
sub deleteFile {
	my ( $self, $ref_fileName ) = @_;
	print "deleting file $$ref_fileName\n";
	return -1 if (!defined($ref_fileName) );
	unlink($$ref_fileName) or warn "Could not unlink $$ref_fileName: $!";
	return 0;
}

# ![7]
sub renameFile {
	my ( $self, $ref_fileNameOld, $ref_fileNameNew ) = @_;
	return -1 if (!defined($ref_fileNameOld) || !defined($ref_fileNameNew));
	print "renameFile\n";
	print "$$ref_fileNameOld\n";
	my $fn = basename($$ref_fileNameOld);
	print "first basenameis: $fn\n";
	print "second name is: $$ref_fileNameNew\n";
	rename($$ref_fileNameOld, $$ref_fileNameNew) || die "Cannot rename $$ref_fileNameOld with $$ref_fileNameNew - $!";
	return 0;
}

# ![8]
sub autoRename {
	my ( $self ) = @_;
	# first delete the old original file
	my $err = deleteFile($self,\$self->{_fileName});
	return -1 if ($err != 0);
	# rename the file tmp with the original name
	$err = renameFile($self, \$self->{_tmpFileName}, \$self->{_fileName});
	return -1 if ($err != 0);
	return 0;
}

# ![9]
sub writeSignatureToFile {
	my ($self, $File) = @_;
	
	open MANIPULATE, '>>', $File or 
		croak "cannot open file for reading of $$refFile, $!.\n";

	flock MANIPULATE, LOCK_EX;
	
	# at the end add the signature
	print MANIPULATE writeSignature();
	
	flock MANIPULATE, LOCK_UN;
	close MANIPULATE or croak "Unable to close $$refFile, $!.\n";	
}

# ![10]
sub setFormatting {
	my ($self, @array) = @_;
	do {
		@{$self->{formattingOptions}} = ();
		@{$self->{formattingOptions}} = @array;
	} if (@array);  
}

sub getFormatting {
	print "getformatting\n";
	my ($self) = shift;
	return $self->{formattingOptions};
}
1;