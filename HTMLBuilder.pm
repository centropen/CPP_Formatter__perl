#!/usr/bin/perl 
package HTMLBuilder;

use warnings;
use strict;
use Data::Dumper;
use HTML::Template;
use File::Spec;
use File::Basename;
use URI::file;
use Carp;

=head1 NAME
HTMLBuilder - global package for html report files; consisted only of public methods.
=cut

=head2 PUBLIC SECTION
=cut

=head3 GenerateWebSite()
=cut

our $VERSION = '0.0.1';

sub GenerateWebSite
{
	my ($tmplPath, $htmlfile, $srcpath, $plusregexp, $minusregexp, 
		$chosenprefix, $cntFiles, $orig_size, $new_size, $dif_size,
		$plscriptname, $username, $version, $JSONFileName, $datetime) = @_;
		
	$datetime = 0 if !defined($datetime);
	print "template file Path: $tmplPath\n\n";	
	print $datetime;
	$dif_size = 0 if !defined($dif_size);
	croak "No JSON data has been defined, please specify some JSON.data!" if !$JSONFileName;
	croak "No HTML file defined!" if !defined($htmlfile);
	$version = $VERSION if !defined($version);
	$username = Win32::LoginName if !defined($username);
	$plscriptname = 'CPP_Formatter' if !defined($plscriptname);
	croak "No Template for HTML genration is defined!" if !defined($tmplPath);
	$srcpath = '?' if !defined($srcpath);
	$plusregexp = '^DbDesc.*\.cpp' if !defined($plusregexp);
	$minusregexp = 'Zusatz.*$' if !defined($minusregexp);
	$chosenprefix = '000_' if !defined($chosenprefix);
	$cntFiles = 'unknown' if !defined $cntFiles;
	$orig_size = 0 if !defined($orig_size);
	$new_size = 0 if !defined($new_size);
		
	my $template = HTML::Template->new(filename => $tmplPath);
	$template->param(
		DATETIME_MESSAGE 	=> $datetime,
		USERNAME_MESSAGE 	=> $username,
		APP_VERSION 		=> $version,
		SRCPATH_MESSAGE		=> $srcpath,
		PLUS_REGEXPRESSION_MESSAGE 	=> $plusregexp,
		MINUS_REGEXPRESSION_MESSAGE => $minusregexp,
		PREFIX_FILE_MESSAGE	=> $chosenprefix,
		CNT_FILES_MESSAGE	=> $cntFiles,
		SUM_ORIG_SIZE_MESSAGE		=> $orig_size,
		SUM_NEW_SIZE_MESSAGE		=> $new_size,
		SUM_DIFF_SIZE_MESSAGE		=> $dif_size,
		PLSCRIPTNAME_MESSAGE		=> $plscriptname,
		JSON_MESSAGE				=> $JSONFileName	
	);	
	
	open FILE, ">", $htmlfile or die "error occurred at $!";
	print FILE $template->output();
	close FILE;	
}

1;