#!/usr/bin/perl

use strict;
use warnings;

use Encode;
use YAML::Any;

my $dat = [];
my $last = [$dat];
my $idx = 0;
while(<>) {
	s/[\r\n]+$//;
	$_ = Encode::decode('euc-jp', $_);

	if(m|<DT>(.*)|) {
		push @$dat, $1;
	} elsif(m|<UL>|) {
		$last->[$idx+1] = [];
		my $key = pop @{$last->[$idx]};
		push @{$last->[$idx]}, +{ $key, $last->[$idx+1] };
		++$idx;
	} elsif(m|</UL>|) {
		--$idx;
	} elsif(m|<LI>(.*)|) {
		push @{$last->[$idx]}, $1;
	}
}
print YAML::Any::Dump($dat);
