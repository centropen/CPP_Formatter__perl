#!/usr/bin/perl 
package RegExpFileSearcher;

use strict;
use warnings;
use File::Spec;        				# file path
use File::Basename qw/ dirname basename /;
use FindBin qw( $RealBin );
use Path::Class;       				# recursive file search -> out
use File::Find::Rule;
use Carp;
use Data::Dumper;

sub new
{
	my ($class, $args) = @_;
	my $self = {
		folderPath			=> $args->{folderPath},
		regExpFileName		=> $args->{regExpFileName} || '^DbDesc.*\.cpp',
		negregExpFileName	=> $args->{negregExpFileName} || '.*Zusatz.*',
		outFileArray		=> [],
		outFileNegArray		=> []
	};
	return bless $self, $class;
}

sub setFolderPath {
	my $self = shift;
	my $folder = shift;
	croak "You have to specify folder in argument!" if ($folder);
	$self->{folderPath} = $folder;	 
}

sub getFolderPath {
	my $self = shift;
	croak "Error, folder isn't set!" if !($self->{folderPath});
	return $self->{folderPath};
}

sub setRegExpression4FileName {
	my $self = shift;
	my $regexp = shift;
	print "Default $self->{regExpFileName} is set, otherwise call setRegExpression4FileName again with argument!\n"
		if !defined($self->{regExpFileName});	
	$self->{regExpFileName} = $regexp;
}

sub getRegExpression4FileName {
	my $self = shift;
	return $self->{regExpFileName};
}

sub setNegRegExpression4FileName {
	my $self = shift;
	my $nregexp = shift;
	print "Default $self->{negregExpFileName} is set, otherwise call setNegRegExpression4FileName again with argument!\n"
		if !defined($self->{negregExpFileName});	
	$self->{negregExpFileName} = $nregexp;
}

sub getNegRegExpression4FileName {
	my $self = shift;
	return $self->{negregExpFileName};
}

sub searchForFiles {
	my $self = shift;
	my $level = shift;
	$level = 20 if !$level;

	
	print "Files will be looked for in depth of $level levels.\n";
	
	my $sobj = File::Find::Rule->file()->name(qr/$self->{regExpFileName}/)
									   ->maxdepth($level)
									   ->start($self->{folderPath});	
	my $iter = 0;								
	while (my $matchedFile = $sobj->match()) {
		my ($name, $ext) = split(/\./, basename($matchedFile));		
		if ($name !~ qr/$self->{negregExpFileName}/) 
		{ 
			++$iter;
			push $self->{outFileArray}, $matchedFile;
			my $mod = $iter % 10;
			print "Handled: $iter files.\n" if ($mod eq 0);
		} else	# save zusatz to negarray
		{
			push $self->{outFileNegArray}, $matchedFile;	
		}
	}
	return $self->{outFileArray};
}

sub getFiles {
	my $self = shift;
	return () if !defined($self->{outFileArray});
	return $self->{outFileArray};	
}

sub getNegFiles {
	my $self = shift;
	return () if !defined($self->{outFileNegArray});
	return $self->{outFileNegArray};	
}

1;