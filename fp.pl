my $test = "    hello   ,   _T(  , jdi do haje,  _T(\"my value\")   ";



##
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

my $result = delSpacesBE($test);
print $result;
