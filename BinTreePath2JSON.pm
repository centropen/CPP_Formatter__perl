package BinTreePath2JSON;

use warnings;
use strict;
use Carp;
use Data::Dumper;
use File::Spec;
use File::Path;
use File::Basename;
use FindBin;
use Tree::Builder;
use JSON::PP;
use POSIX;

=head1 NAME

BinTreePath2JSON - takes an array of strings with the paths and create a binary tree exporting it
				   to the JSON file in a specified folder.			  
=head1 VERSION
Version 0.0.1

=cut
=head1 METHODS
=cut

our $VERSION = '0.0.1';

sub new
{
	#my $class = shift;
	my ($class, $args) = @_;
	my $self = {
		PathList 	=> undef,
		separator	=> $args->{separator} || '/',   #shift,
		rootPath	=> $args->{rootPath} || 'root',
		file		=> undef,
		count		=> 0,
		error		=> 0,
		errorText	=> '',
		outTree		=> undef
		
	};
	bless $self, $class;
	
	if (!defined($self->{separator})) {
		$self->{separator} = '/';
	}
	
	
	return $self;	
}

=head2 getPathList()

getPathList() gets the array of all set Paths in ref. array
			  binTreePath2Json->getPathList();

=cut
sub getPathList {
	my $self = shift; 
	if (!defined($self->{PathList})) {
		$self->{error} = -1;
		$self->{errorText} = "No Input Array of Paths is defined! Please call setPathList(\@list).\n";
		$self->{count} = 0;
	} else {
		$self->{error} = 0;
		$self->{errorText} = '';
	}
	return $self->{PathList};
}

=head2 setPathList(@list)
setPathList(@list) sets the array of all Paths. Obligatory input parameter.
=cut
sub setPathList {
	my ($self, $ref_list) = @_;
	if (!defined($ref_list)) {
		$self->{error} = -1;
		$self->{errorText} = "Input list has not been specified. Please Call setPathList(\@list).\n";
		$self->{count} = 0;
	} else {
		$self->{error} = 0;
		$self->{errorText} = '';
		$self->{count} = scalar(@$ref_list);
	}
	#$$ref_list[0] = 'her';
	$self->{PathList} = $ref_list;
}

=head2 getSeparator()
getSeparator() gets the separator, it's also one optional argument in constructor or can be set explicitelly.
 			   If no is set, then '/' is set automatically.
=cut
sub getSeparator {
	my $self = shift;
	return $self->{separator};
}

=head2 setSeparator()
setSeparator() sets the separator excplicitelly.
=cut
sub setSeparator {
	my ($self, $separator) = @_;
	if (!defined($separator)) {
		$separator = '/';
	}
	$self->{separator} = $separator;
}

=head2 setFile($file)
setFile($file) sets the file name, e.g. data.json, where data will be saved
=cut
sub setFile {
	my ($self, $file) = @_;
	if (!defined($file)) {
		# save it in the same folder as the project timestamp
		my $timestamp = POSIX::strftime("%Y%m%d%H%M%S", localtime); 
		print "my stamp: $timestamp\n";
		$file = File::Spec->catfile(dirname($0), $timestamp.'.json');
		$self->{file} = File::Spec->rel2abs($file);
	}
	$self->{file} = File::Spec->rel2abs($file);
	print "file in member: $self->{file}\n";
}

=head2 getFile()
getFile() gets the file name, where data will be saved
=cut
sub getFile {
	my ($self) = shift;
	if (!defined($self->{file})) {
		# save it in the same folder as the project timestamp
		my $timestamp = POSIX::strftime("%Y%m%d%H%M%S", localtime); 
		$self->{file} = File::Spec->rel2abs($timestamp."\.json");
	} 
	return $self->{file};
}

=head2 getFileNameHelper()
getFileNameHelper() gets only filename in form: %Y%m%d%H%M%S.json
=cut
sub getFileNameHelper()
{
	my ($self) = shift;
	return POSIX::strftime("%Y%m%d%H%M%S",localtime)."\.json";
} 

=head2 count()
count() gets the count of elements in Array
=cut
sub count()
{
	my ($self) = shift;
	if (!defined($self->{PathList})) {
		$self->{count} = 0;
		return 0;
	}
	my $ref = $self->{PathList};
	return scalar(@$ref);
}

=head2 getError()
getError() gets the error number, 0 = OK
								 -1 = Not enough input parameter
								  1 = Error, program will be terminated.
=cut
sub getError {
	my $self = shift;
	return $self->{error};
}

=head2 getErrorText()
getErrorText() gets the error text, where the error is more exact.
=cut
sub getErrorText {
	my $self = shift;
	return $self->{errorText};
}

=head2 add2List($element)
add2List($element) adds to the end new element
=cut
sub add2List {
	my $self = shift;
	my $elem = shift;
	if (!defined($elem) or !defined($self->{PathList})) {
		return;
	}
	push $self->{PathList}, $elem;	
}

=head2 getPureTree(ref @list)
getPureTree(ref @list) returns reference to hashed tree structure
This method ought to be used as private class, but can be used outside
=cut
sub getPureTree
{
	my $self = shift;
	my $tree = shift;	# input reference, back reference
	my $ref2List = $self->{PathList};
	if (scalar(@$ref2List) eq 0) {
		$self->{error} = -1;
		$self->{errorText} = "The list is empty, please call setPathList(\@list) before.\n";
		return undef;
	}
	my $tb = Tree::Builder->new();
	$tb->setSeperator(getSeparator($self));
	foreach my $elem(@$ref2List) {
		$tb->add($elem);
	}
	%$tree = $tb->getTree();
	return $tree;	
}

=head2 transform(ref %tree)
transform(ref %tree) transforms already prepared tree structure and inserts keywords for json file
before must be called method getPureTree, output is input for this method.
=cut
sub transform {
	my $self = shift;
	my $tree = shift;
	my @children = ();
	while (my ($name, $children) = each %$tree) {
        push @children, {
            name => $name,
            children => [ transform($self, $children) ],
        }
    }
    return @children;
}

=head2 getTreeForJSON()
getTreeForJSON() returns reference to hash with final JSON structure, in this structure will be saved
the JSON file.
=cut
sub getTreeForJSON {
	my $self = shift;
	my %tree;
	my $reftree = getPureTree($self, \%tree);
	
	$self->{outTree} = {name => $self->{rootPath}, children => [transform($self, $reftree)] };
	return $self->{outTree};
}

=head2 DumpJSON()
DumpJSON() prints the JSON in human readable form.
=cut
sub DumpJSON {
	my $self = shift;
	if (!defined($self->{outTree})) {
		getTreeForJSON(shift);
	}
	my $json = JSON::PP->new->pretty;
	print $json->encode($self->{outTree});	
}

=head2 getJSON()
getJSON() returns simple string
=cut
sub getJSON {
	my $self = shift;
	if (!defined($self->{outTree})) {
		getTreeForJSON($self);
	}
	my $json = encode_json $self->{outTree};
	return $json;
}

=haed2 save2JSON()
save2JSON() save to file
=cut
sub save2JSON {
	my $self = shift;
	my $json = getJSON($self);
	if (!defined($json)) {
		$self->{error} = 1;
		$self->{errorText} = "No json object can be created, no tree container created before.";
		return 1;
	}
	open INJSONFILE, '>', $self->{file} or die "The file <$self->{file}> couldn't be created - $!.";
	print INJSONFILE $json;
	close INJSONFILE;
	return 0;		
}
1;