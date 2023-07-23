#!/usr/bin/perl

use utf8;
use strict;
use warnings;

use Encode;
use Time::Local;
use YAML::Any;
use XML::FeedPP;
use IO::Scalar;

my $HTML_ENCODE = 'UTF-8';
my $META_THR = 30;
my $BASE_URL = 'https://yakex.dev/junks/';
my $TARGET_FOLDER = '/home/atarashi/work/www/data/junks';

sub outtree
{
    my ($fh, $data) = @_;

	if(ref($data) eq 'ARRAY') {
		print $fh "<UL>\n";
		foreach my $entry (@$data) {
			outtree($fh, $entry);
		}
		print $fh "</UL>\n";
	} elsif(ref($data) eq 'HASH') {
		my ($key, $title);
		if(exists $data->{content}) {
			$key = 'content';
			$title = $data->{title};
		} else {
			($key) = keys %$data;
			$title = $key;
		}
		print $fh '<LI>',Encode::encode($HTML_ENCODE, $title),"\n";
		outtree($fh, $data->{$key});
	} else {
		$data =~ s/\s+$//;
		print $fh '<LI>',Encode::encode($HTML_ENCODE, $data),"\n";
	}
}

sub outtree_meta
{
	my ($fh, $data, $lv) = @_;

	if(ref($data) eq 'ARRAY') {
		foreach my $entry (@$data) {
			outtree_meta($fh, $entry, $lv + 1);
		}
	} elsif(ref($data) eq 'HASH') {
		my ($key, $title);
		if(exists $data->{content}) {
			$key = 'content';
			$title = $data->{title};
		} else {
			($key) = keys %$data;
			$title = $key;
		}
		print $fh ('　' x $lv),'・',$title,"\n";
		outtree_meta($fh, $data->{$key}, $lv);
	} else {
		$data =~ s/\s+$//;
		print $fh ('　' x $lv),'・'.$data,"\n";
	}
}

sub outtree_atom
{
	my ($obj, $data, $date) = @_;

	if(ref($data) eq 'ARRAY') {
		foreach my $entry (@$data) {
			outtree_atom($obj, $entry, $date);
		}
	} elsif(ref($data) eq 'HASH') {
		my ($key, $title);
		if(exists $data->{content}) {
			my @content_attr;
			@content_attr = (type => 'html') if ref($obj) =~ /Atom/;
			my $content;
			my $fh = IO::Scalar->new(\$content);
			outtree($fh, $data->{content});
			$obj->add_item(
				author => 'yak_ex@mx.scn.tv',
				link => $BASE_URL.$data->{url},
				title => $data->{title},
				pubDate => $date,
			)->description(Encode::decode($HTML_ENCODE, $content), @content_attr);
		} else {
			($key) = keys %$data;
			outtree_atom($obj, $data->{$key}, $date);
		}
	}
}

my $dat = YAML::Any::LoadFile('history.yaml');

my %types = (
	'XML::FeedPP::Atom::Atom10' => '.atom',
	'XML::FeedPP::RSS' => '.rss',
	'XML::FeedPP::RDF' => '.rdf',
);

{ # Atom/RSS/RDF
	foreach my $type (keys %types) {
		my $atom = $type->new;
		$atom->title('物置');
		$atom->link($BASE_URL);
		$atom->description('物置') if $types{$type} ne '.atom';
		$atom->pubDate(time);
		foreach my $date (@$dat) {
			my ($key) = keys %$date;
			my @date = split m|/|, $key;
			my $time = timelocal(0,0,0,$date[2],$date[1]-1,$date[0]);
			outtree_atom($atom, $date->{$key}, $time);
		}
		$atom->set('id' => $BASE_URL) if $types{$type} eq '.atom';
		$atom->uniq_item;
		$atom->to_file($TARGET_FOLDER.'/history'.$types{$type});
	}
}

my $meta;

{ # META
	my $out = 0;
	my $fh = IO::Scalar->new(\$meta);
	print $fh "<META NAME=\"WWWC\" CONTENT=\"\n";
	foreach my $date (@$dat) {
		my ($key) = keys %$date;
		my @date = split m|/|, $key;
		my $time = timelocal(0,0,0,$date[2],$date[1]-1,$date[0]);
		last if $out && time() - $time > 60*60*24* $META_THR;
		print $fh '[',$key,"]\n";
		outtree_meta($fh, $date->{$key}, -1);
		$out = 1;
	}
	print $fh "\">\n";
	close $fh;
}

{ # HTML - history
	open my $fh, '>', $TARGET_FOLDER.'/history.html';
	print $fh Encode::encode($HTML_ENCODE, <<HEADER);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<HTML lang="ja">
<HEAD>
<META http-equiv="Content-Type" content="text/html;charset=$HTML_ENCODE">
<LINK rel="stylesheet" href="style.css" type="text/css">
<LINK rel="alternate" type="application/atom+xml" title="Atom" href="history.atom">
<LINK rel="alternate" type="application/rss+xml" title="RSS" href="history.rdf">
<LINK rel="alternate" type="application/rss+xml" title="RSS2" href="history.rss">
$meta<TITLE>物置履歴</TITLE>
</HEAD>
<BODY>
<H2>物置履歴</H2>
<HR>
<DL>
HEADER
	foreach my $date (@$dat) {
		my ($key) = keys %$date;
		print $fh '<DT>',$key,"\n<DD>\n";
		outtree($fh, $date->{$key});
	}
	print $fh Encode::encode($HTML_ENCODE, <<'FOOTER');
</DL>
<HR>
<P id="html-validator"><A href="http://validator.w3.org/check?uri=referer"><IMG class="banner" src="http://www.w3.org/Icons/valid-html401" alt="Valid HTML 4.01!" height="31" width="88"></A></P>
<P id="css-validator"><A href="http://jigsaw.w3.org/css-validator/check/referer"><IMG class="banner" src="http://jigsaw.w3.org/css-validator/images/vcss" alt="Valid CSS!" height="31" width="88"></A></P>
<P id="footer-notice">Last modified: $Date$ <BR>
Written by 「や」/ <A href="mailto:yak_ex@mx.scn.tv">Yak!</A></P>
</BODY>
</HTML>
FOOTER
	close $fh;
}

{ # HTML - index
	open my $fh, '<', $TARGET_FOLDER.'/index.html';
	open my $fhout, '>', $TARGET_FOLDER.'/index.html.out';
	my $inmeta = 0;
	while(<$fh>) {
		if(/<META NAME="WWWC" CONTENT="/) {
			$inmeta = 1;
			print $fhout Encode::encode($HTML_ENCODE, $meta);
		}
		print $fhout $_ if ! $inmeta;
		if(/^">/) {
			$inmeta = 0;
		}
	}
	close $fhout;
	close $fh;
	rename $TARGET_FOLDER.'/index.html.out', $TARGET_FOLDER.'/index.html';
}
