package BinTreePath;

use warnings;
use strict;

=head1 NAME

BinTreePath - takes path in string and convert it to json object with 
			  name and array inside.
			  
=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

sub new
{
		my $class = shift;
		my $self = {
			tree			=> {},
			separator		=> shift
		};
		bless $self;
		
		if (!defined($self->{separator})) {
			$self->{separator} = '/';
		}
		return $self;
}

sub add
{
	my ($self, $item) = @_;
	if (!defined($item)) {
		warn('BinTreePath add: no item for adding has been defined!');
		return undef;
	}
	my @items = split(/$self->{separator}/, $item);
	
	# empty storage for children
	my %arrayLower = { 'name', 'children'};
	my @refArray = ();
	push @refArray, \%arrayLower;
	
	# first initialize the tree
	if (!defined($self->{tree}{'name'}[0])) {
		$self->{tree}{'name'}[0] = $items[0];
		$self->{tree}{'children'}[0] = \@refArray;
	}
	# if item doesnt exist return
	if (!defined($items[1])) {
		return 1;
	}
	my %newHash = %{$self->{tree}[0]};
	my %newHash2=$self->addSub(\%newHash, \@items, 1);
	
	return 1;	
}
	
sub addSub {
	my $self=$_[0];
	my %hash=%{$_[1]};
	my @items=@{$_[2]}; # next item in stringlsit
	my $int = $_[3];
	
	#return hash if there is nothing further
	if (!defined($items[$int])) {
		return %hash;
	}
	
	# add a new hash if it does not already exist
	if (!defined($hash{'name'}[$int])) {
	
#		my %arrayLower = { 'name', 'children'};
#	my @refArray = ();
#	push @refArray, \%arrayLower;
#		$hash{'name'}[$int] = $items[$int];
	}
	
#	my %newhash = 
	
	return %hash;
}
	
	#my %newhash = %{$self->{tree}}
	