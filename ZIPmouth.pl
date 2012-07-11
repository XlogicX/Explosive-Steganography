#!/usr/bin/perl
#ZIPmouth
use strict;
use warnings;
use Crypt::Rijndael;
use Getopt::Long;

#INIT VARS
        my $index = 1;			#Used for looping
        my @characters;			#used to count characters in a string
        my $count;			#The amount of characters in a string
        my $decrypted;			#decrypted plaintext version of data
        my $iv = "Jqfmc.68=-MMt;kz";	#Initialization Vector for crypto
        my $plaintext;			#the input file is contained in here
        my $password = 0;		#password is contained in here
	my $cipher;			#used for crypto module
	my $inject = 0;			#set to '1' if use wants to encrypt
	my $crypted;			#encrypted version of data
	my $extract = 0;		#set to '1' if user wants to decrypt
	my $inputfile = 0;		#user supplied input file
	my $hostfile = 0;		#user supplied host file (a pure .zip)
	my $outputfile = 0;		#user supplied output file
	my $verbose = 0;		#set to '1' if user wants verbosity
	my $insane = 0;			#set to '1' if user input doesn't make sense
	my $hostdata;

getoptions();				#Gets user supplied options
docs();					#Prints documentation if there are no valid options present
sanity();				#makes sure the options aren't retarded
filehandles();				#sets up the file handles
setcipher();				#sets up the crypto cipher

if ($inject eq 1) {			#if user wants to encrypt, call encrypt();
	encrypt();
}

if ($extract eq 1) {			#if user wants to decrypt, call decrypt();
	decrypt();
}

################################## End of Program ###########################################

sub filehandles {
	if ($inject eq 1) {			#If user wants to encrypt, the input file would be plaintext
        	open PLAIN, "$inputfile";	
	} else {				#otherwise, it would be crypted
		open CRYPT, "$inputfile";
	}
	open HOST, "$hostfile";
        open OUT, ">$outputfile";		#output filehandle is OUT
}

sub getoptions {
	GetOptions('password=s' => \$password,		#get password
			'inject' => \$inject,		#encrypt?
			'extract' => \$extract,		#decrypt?
			'infile=s' => \$inputfile,	#input file
			'outfile=s' => \$outputfile,	#output file
			'hostfile=s' => \$hostfile,	#.zip host file
			'verbose' => \$verbose,)
}

sub setcipher {
	while (1) {					#padding routine
        	@characters = split //, $password;	#@characters array has each individual character of password
        	$count = @characters;			#counts those caracters
        	last if $count % 32 == 0;		#if the password is the keysize (32), then we're good
        	$password .= "X";			#otherwise, pad an "X" at the end and check again
	}						#lame, I know, but it works great, and is still secure enough
	$cipher = Crypt::Rijndael->new( $password, Crypt::Rijndael::MODE_CBC() );	#get the cipher
	$cipher -> set_iv($iv);								#set the IV
}

sub encrypt {

	$/=undef;								#Fuck newlines
	$plaintext = <PLAIN>;							#put the whole plaintext file into $plaintext
	$hostdata = <HOST>;							#get original .zip into hostdata var
	$/="\n";								#Ok, newlines are cool again
	if ($password ne "0XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") {
		while (1) {
        		@characters = split //, $plaintext;		#padding routine again. To encrypt, the input data has to be in
        		$count = @characters;				#multiples of 16 bytes. If it's not, it just adds 'X's until
        		last if $count % 16 == 0;			#it is divisible by 16. The decryption has to parse this shit
        		$plaintext .= "X";				#out though. It's not perfect yet. If your plaintext ended in
		}							#The letter 'X'...too bad, it wont after decryption, meh, my
								#code sucks, get over it.
		$crypted = $cipher->encrypt($plaintext);		#Encrypt the data
		print OUT "$hostdata";
		print OUT "\x50\x4b\x13\x37";
		print OUT "$crypted";					#put it in our output file after the zip file contents
	} else {
		print OUT "$hostdata";
		print OUT "\x50\x4b\x13\x37";
		print OUT "$plaintext";
	}
}

sub decrypt {
	$/=undef;						#Fuck newlines
	$crypted = <CRYPT>;					#put the whole encrypted file into $crypted
	$/="\n";						#Ok, newlines are cool again
	if ($password ne "0XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") {
		if ($crypted =~ /\x50\x4b\x13\x37(.+)$/s) {;		#replace Header+Data+Footer with nothing; removes virus sig
			$decrypted = $cipher -> decrypt($1);		#decrypt it now
			$decrypted =~ s/\nX+//;				#get rid of the padded X's and a newline
			$decrypted .= "\n";				#add newline back in
			print OUT $decrypted;				#output the decrypted data to a file
		} else {print "no match1\n";}
	} else {
		if ($crypted =~ /\x50\x4b\x13\x37(.+)$/s) {;
			print OUT $1;;
		} else {print "no match2\n";}
	}
}

sub docs {		#if no options are selected, print this information on how to use the tool
	if (($password eq 0) && ($inject eq 0) && ($extract eq 0) && ($inputfile eq 0) && ($outputfile eq 0)) {
		print "\nZIPmouth\n";
		print "Usage: ZIPmouth.pl {--password=userdefined} {encode/decode --inject or --extract}\n";
		print "\t{--infile=file.ext} {--outfile=file.ext}\n";
		print "\n";
		print "OPTIONS:\n";
		print "\t--verbose: Increases verbosity of output\n";
		print "\t--password: enter a password to protect the encrypted message\n";
		print "\t--inject: This option encrypts a message\n";
		print "\t--extract: This option decrypts a message\n";
		print "\t--infile: If encrypting, this is the 'plaintext' file. If decrypting, it is the encrypted\n";
		print "\t\t.zip file.\n";
		print "\t--hostfile: This is the .zip file we will be attaching our encrypted data to\n";
		print "\t--outfile: If encrypting, this is the output .zip file, if decrypting, it is the\n";
		print "\t\t'plaintext' file you would like to output into.\n";
		print "EXAMPLES:\n";
		print "\tZIPmouth.pl --password=password --inject --infile=plaintext.txt --outfile=compressed.zip --hostfile=r.zip\n";
		print "\t\tThis encrypts plaintext.txt with password of 'password' and saves it in compressed.zip\n";
		print "\tZIPmouth.pl --password=password --extract --infile=compressed.zip --outfile=plaintext2.txt\n";
		print "\t\tThis decrypts the message in compressed.zip with password of 'password' and\n";
		print "\t\toutputs the message to plaintext2.txt\n";
		exit 0;
	}
}

sub sanity {
	if (($inject eq 1) && ($extract eq 1)) {	#if user is trying to encrypt and decrypt at the same time
        	print "You can't encrypt and decrypt at the same time\n\n";
        	$insane = 1;
	}
	
	if ($inputfile eq 0) {			#if user didn't provide an input file
		print "You need an input file, whether it's a plaintext or crypted file\n";
		print "The option for that is infile=input.file\n\n";
		$insane = 1;
	}

	if ($outputfile eq 0) {			#if user didn't provide an output file
		print "You need an output file, whether it's a crypted or plaintext file\n";
		print "The option for that is outfile=output.file\n\n";
		$insane = 1;
	}
	
	if ($insane) {				#quit if any of the above happened
		exit 0;
	}

	if (-e $outputfile) {			#if output file already exists, see if user meant this
		print "Hey, $outputfile already exists, proceed anyway?\n";
		my $choice = <STDIN>;
		chomp $choice;
		if ($choice !~ /^y(\w+)?/i) {
			print "Ok, just make sure you run again with one that doesn't exist\n";
			exit 0;
		}
	}

	if (-e $inputfile) {			#if the input file doesn't exist, let them know of their typo
	} else {
		print "The file '$inputfile' doesn't exist, try another file.\n";
		exit 0;
	} 

}
