#!/usr/bin/perl
#Version 1.017
#My first perl script; coding conventions may not be consistent... ;)
use warnings;
use strict;
use Getopt::Long;
use Time::HiRes;
use Crypt::Rijndael;

#When did program start
my $start = Time::HiRes::time();

#The Big Group of VARS
my $verbose = 0;		#0=no, 1=yes
my $multiplier = 1;		#default runs through once, unless specified more times
my $magical_secret = "LOL";	#LOL is the header for the stego chunks
my $magical_end = "LULZ";	#LULZ is the footer for the stego chunks (placed in only twice)
my $osaur = 0;			#Are we adding stegonography? 0=no, 1=yes
my $extract = 0;		#flag to see if we want to extract stego
my $password = 0;			#password for either encryption/decryption
my $padding = 0;
my $padclone;
my $packed = 0;
documentation();
getargs();
my $inputfile = shift @ARGV;	#Get the input .conf file
my $outputfile = shift @ARGV;	#filename to write to
my $secretfile = shift @ARGV;	#file to stego

sanity();
filehandles();

##################################---Init Strings/Arrays---################################################
my @types;	#file types
my @headers;	#headers
my @footers;	#footers
my @sizes;	#stop sizes for each file type
my $smallestsize;
my @fields;	#array to store the fileds of each line of a .conf (at a time)
my $index = 0;	#general purpose counter for arrays
my $secret;
$/ = undef;
if ($secretfile) {
        $secret = <INSECRET>;	#if there was a secret file, put the contents into $secret
}
$/ = "\n";	#ok, back to normal newline seperator
#Payload strings/arrays
my @characters;				#Individual characters in a header/footer
my $charactercount;			#The amount of those characters
my $printindex = 0;			#Where on the @characters to print from
my $initial_multiplier = $multiplier;	#non-destructive version of $multiplier
my $last_footer_flag = 0;		#Just a flag that gets set to stop printing stego footers
my $arraysize;				#size of the parsed .conf array
my $percentage = 10;			#holds 10 percent increments of program progress
my $stegod = 0;				#set the flag after making stego chunk
my $count;				#The amount of characters in a string
my $cipher;				#used for crypto module
my $iv = "Jqfmc.68=-MMt;kz";		#Initialization Vector for crypto
my $plaintext;				#the input file is contained in here
my $crypted;				#encrypted version of data
my $decrypted;				#decrypted plaintext version of data
my $random;
my $headerssize;
my $footerssize;
my $stegosize = 0;
##################################---Init Strings/Arrays---################################################ 

if ($extract eq 0) {
	moresanity();
}
if ($extract eq 0) {
	parseconf();	#parse the conf file (assuming we are not extracting)
}
if ($extract eq 0) {
	verbosity();
}
if ($osaur eq 1) {
	setcipher();	#sets up the crypto cipher
}
if ($packed eq 1) {
	bangforbuck();
}
if ($extract eq 0) {
	createbomb();
}
if ($extract eq 1) {
	extract();
}



finishhim();


sub documentation {
####################################---Documentation---####################################################
#checks if there is any arguments and quits if not...There's gotta be a better way to do this, but this
#works.
if (@ARGV){
	} else {
	print "Magic Bomb 0.102\n";
	print "Usage: magicbomb.pl [options] {input configuration file} {output payload file} [secret file]\n";
	print "OPTIONS:\n";
	print "\t--verbose: displays what file types / headers / footers have been picked up\n";
	print "\t\tfrom the configuration file. This would be for troubleshooting purposes\n";
	print "\t--multiplier: Effects how many times the payload repeats, for greater effectiveness.\n";
	print "\t\tThe default value is 1, it is recommended to use much larger values than this.\n";
	print "\t\tAn example of repeating the payload 30 times would look like this:\n";
	print "\t\t\t--multiplier=30\n";
	print "\n";
	print "STEGANOGRAPHY OPTIONS\n";
	print "\t--osaur: This option enables the below steganography options:\n";
	print "\t\t\t(Usage without --osaur will not give errors, but they will not work either)\n";
	print "\t\t\t([secret file] required with the --osaur option\n";
	print "\t\t--magicsecret: This is the user-defined header name that precedes stego chunks.\n";
	print "\t\t\tAn example would look like this: --magicsecret=LOL\n";
	print "\t\t\tIf no value is supplied, the default is 'LOL'\n";
	print "\t\t--magicend: This is the user-defined footer name. It only appears twice though.\n";
	print "\t\t\tThe footer is used on the first and last chunk. If no value is supplied, the\n";
	print "\t\t\tdefault is 'LULZ'.\n";
	print "\t\t--password: Use this to encrypt/decrypt the stego (optional)\n";
	print "\n";
	print "EXAMPLES:\n";
	print "\tmagicbomb.pl --multiplier=1000 scalpel.conf output.dd\n";
	print "\t\tTakes files from scalpel.conf and makes a payload, repeats 1000 times,\n";
	print "\t\tsaves it as output.dd\n";
	print "\tmagicbomb.pl --multiplier=6000 --osaur --password=lol --magicsecret=STE --magicend=GO scalpel.conf out.dd plaintext.txt\n";
	print "\t\tpassword protects message in plaintext.txt with password of 'lol' into\n";
	print "\t\tmagicbomb out.dd. Stego has custom header/footer of STE/GO\n";
	print "\tmagicbomb.pl --osaur --password=lol --extract --magicsecret=STE --magicend=GO out.dd decrypted.txt\n";
	print "\t\tThe command to decrypt the example before this one into decrypted.txt\n";
	die
}

####################################---Documentation---####################################################
}

sub getargs {
####################################---Get Arguments---####################################################
	GetOptions('verbose' => \$verbose, 
			'multiplier=s' => \$multiplier,
			'magicsecret=s' => \$magical_secret,
			'magicend=s' => \$magical_end,
			'osaur' => \$osaur,
			'extract' => \$extract,
			'password=s' => \$password,
			'padding=s' => \$padding,
			'packed' => \$packed);
####################################---Get Arguments---####################################################
}

sub sanity {
###############################---Some Modest Error Checking---############################################
#Check for --osaur Option Conflicts
if ($secretfile && ($osaur eq 0)){
	print "You're doing it wrong; you can't use a secret file without the --osaur option\n";
	die
}

#Check for --osaur Option Conflicts
if ($secretfile) {
# do nothing
} else {
	if (($osaur eq 1) && ($extract ne 1)) {
		print "You're doing it wrong; why would you use --osaur without a file to stego?\n";
		die
	}
}

#Check to see if output file already exists
if (-e $outputfile) {
	print "Hey, $outputfile already exists, proceed anyway?\n";
	my $choice = <STDIN>;
	chomp $choice;
	if ($choice !~ /^y(\w+)?/i) {
		print "Ok, just make sure to run again with one that doesn't exist\n";
		die
	}
}
###############################---Some Modest Error Checking---############################################ 
}

sub filehandles {
####################################---Init the Files---###################################################
open IN, $inputfile or die "The file has to actually exist, try again $!\n";	#input filehandle is IN
open OVEROUT, ">$outputfile" or die "You don't have permissions to write that file $!\n"; #output is OVEROUT
binmode OVEROUT;
open APPENOUT, ">>$outputfile" or die "You don't have the permissions to write that file $!\n"; #appended OUT
binmode APPENOUT;
if ($secretfile) {
	open INSECRET, $secretfile or die "The file has to actually exist, try again $!\n";
		#input filehandle for stego, only Init's it if the arguement was passed for it
	binmode INSECRET;
}
####################################---Init the Files---################################################### 
}

sub moresanity {
##############################---Stego False Positive Killer---############################################ 
if ($secret) {
	if ($secret =~ /$magical_secret/) {
        	print "Please use a different stego header; the one you picked: '$magical_secret', conflicts with the encoded message\n";
	}
	if ($secret =~ /$magical_end/) {
        	print "Please use a different stego footer; the one you picked: '$magical_end', conflicts with the encoded message\n";
	}
}
##############################---Stego False Positive Killer---############################################ 
}

sub parseconf {
###############################---Get Headers/Footers/Types---############################################# 
# The routine that reads and parses the .conf file into the bits that we want
while (<IN>) {						#for each line of the input file
	@fields = split /\s+/, $_;			#make a space seperated array for line
	#if the line exists, AND if it doesn't start with a #, AND if the first piece is an actual word
	if ((@fields) && ($fields[0] !~ /^#/) && ($fields[1] =~ /\w+/)) {
		$types[$index] = $fields[1];		#put file type in current index of @types array
		$headers[$index] = $fields[4];		#put header in current index of @headers array
		$footers[$index] = $fields[5];		#put footer in current index of @footers array
		$index++;				#increment the index
	}
}
###############################---Get Headers/Footers/Types---############################################# 
}

sub verbosity {
##############################---Display Data that Got Parsed---########################################### 
$index = 0;	#reset the general purpose index
if ($verbose eq 1) {
	foreach (@types) {	#for all of the elements in each array (all 3 arrays have same ammount)
		#print the Type of file, Header, and Footer in one line
		print "Type: $types[$index] \tHeader: $headers[$index]";	#we know we have types and headers; print those
		if ($footers[$index]) {						#check for existence of a footer
			print " \tFooter: $footers[$index]";			#print the footer
		}
		print "\n";
		$index++;	#go to the next element in the arrays
	}
}
##############################---Display Data that Got Parsed---###########################################
}


sub createbomb {
  #******************************************************************************************************#
 #					Create the Payload						#
#******************************************************************************************************#
#Loop through printing headers then footers x times. 1 time is the default, unless changed with the
#--multiplier switch

print "Creating payload\n";

#Start the file with MagicBomb header
print OVEROUT "X";

select APPENOUT; #redirects print to APPENOUT
while ($multiplier > 0) {

if ((100 - (($multiplier / $initial_multiplier) * 100)) > $percentage) {
	print STDOUT "$percentage%";
	$percentage = $percentage + 10;
	print STDOUT "\n";
}
###############################---Get Headers/Footers/Types---#############################################
#Since handling all of the fields is implemented in a destructive way, This loop needs to grab the contents
#of the .conf file for every run through. In the future, I could grab non-destructive/destrucive pairs to
#reduce I/0. Even if not, the below should be a "function" since this is just duplicate code...but I
#haven't read the chapter on methods.
	$index = 0;
	close IN;
	open IN, $inputfile or die "The file has to actually exist, try again $!\n";
	while (<IN>) {                                          #for each line of the input file
        	@fields = split /\s+/, $_;                      #make a space seperated array for line
        	#if the line exists, AND if it doesn't start with a #, AND if the first piece is an actual word
        	if ((@fields) && ($fields[0] !~ /^#/) && ($fields[1] =~ /\w+/)) {
                	$types[$index] = $fields[1];            #put file type in current index of @types array
                	$headers[$index] = $fields[4];          #put header in current index of @headers array
                	$footers[$index] = $fields[5];          #put footer in current index of @footers array
                	$index++;                               #increment the index
        	}
	}
###############################---Get Headers/Footers/Types---#############################################


################################---Print All of the Headers---#############################################
	$index = 0;
	foreach (@headers) {								  #For every Header
		if ($headers[$index]) {						 #If the Header is not null
			@characters = split //, $headers[$index];      #Rip the characters into @characters
			$charactercount = @characters;		  	   #Count how many chars there were
			$printindex = 0;			
			while ($printindex < $charactercount) {		   #while the index is < # of chars
				if ($headers[$index] !~ /^\\x\w\w/) {		   #if first char isn't HEX
					print $characters[$printindex];       #print a plain ASCII	
					$headers[$index] =~ s/.//;	       #rip the first character out
					$printindex++;				      #increment index by 1
				} else {					      #Otherwise it was HEX
					if ($headers[$index] =~ /(\\x..)/) {  #Get the matching hex into $1
						print pack("C*", map { $_ ? hex($_) :() } split(/\\x/, $1));
											   #print it as HEX
						$headers[$index] =~ s/....//;#rip out 4 chars (since hex takes 4)
					}
					$printindex = $printindex + 4;		      #increment index by 4
				}
			}
		}
		$index++;						#We're going to the next Header now		
	}
################################---Print All of the Headers---#############################################

#########################################---Padding---#####################################################
	padded();
#########################################---Padding---#####################################################

##################################---Print A Chunk of Stego---#############################################
	if (($osaur eq 1) && ($stegod eq 0)) {					      #If user specified the --osaur switch
		$index = 0;			
		$/ = undef;
		print $magical_secret;		#Start with stego header
	if ($password ne "0XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") {
		$plaintext = $secret;
		while (1) {
        		@characters = split //, $plaintext;		#padding routine again. To encrypt, the input data has to be in
        		$count = @characters;				#multiples of 16 bytes. If it's not, it just adds 'X's until
        		last if $count % 16 == 0;			#it is divisible by 16. The decryption has to parse this shit
        		$plaintext .= "X";				#out though. It's not perfect yet. If your plaintext ended in
		}							#The letter 'X'...too bad, it wont after decryption, meh, my
									#code sucks, get over it.
		$crypted = $cipher->encrypt($plaintext);		#Encrypt the data
		print "$crypted";					#put it in our output file after the zip file contents
	} else {
		print $secret;
	}

		print $magical_end;		#print the stego footer after chunk
		$/ = "\n";
		$stegod = 1;
	}

##################################---Print A Chunk of Stego---#############################################


################################---Print All of the Footers---#############################################
	$index = 0;
	$arraysize = @headers;						     #Determine size of .conf array
	while ($index < ($arraysize)) {					  #Go through each element of array
		if ($footers[$index]) {							  #For every Footer
                        @characters = split //, $footers[$index];      #Rip the characters into @characters
                        $charactercount = @characters;			   #Count how many chars there were
                        $printindex = 0;			
                        while ($printindex < $charactercount) {		   #while the index is < # of chars
                                if ($footers[$index] !~ /^\\x\w\w/) {		   #if first char isn't HEX
                                        print $characters[$printindex];       #print a plain ASCII
                                        $footers[$index] =~ s/.//;	       #rip the first character out
                                        $printindex++;				      #increment index by 1
                                } else {					
                                        if ($footers[$index] =~ /(\\x..)/) {	      #Otherwise it was HEX
                                                print pack("C*", map { $_ ? hex($_) :() } split(/\\x/, $1));
											   #print it as HEX
                                                $footers[$index] =~ s/....//;#rip out 4 chars (since hex takes 4)
                                        }
                                        $printindex = $printindex + 4;		      #increment index by 4
                                }
                        }
		}
		$index++;						#We're going to the next Footer now
	}
################################---Print All of the Footers---#############################################

$multiplier--;	#We're potentially going to the next round of Magic numbers (Headers/Stegos/Padders/Footers)
}
select STDOUT; #return printing to standard out
  #******************************************************************************************************#
 #                                      Payload Finished                                                #
#******************************************************************************************************#
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

sub extract {
	$/=undef;						#Fuck newlines
	$crypted = <IN>;					#put the whole encrypted file into $crypted
	$/="\n";						#Ok, newlines are cool again
	if ($crypted =~ /($magical_secret)(.+)($magical_end)/s) {;		#replace Header+Data+Footer with nothing; removes virus sig
		if ($password ne "0XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") {
			$decrypted = $cipher -> decrypt($2);		#decrypt it now
			$decrypted =~ s/\nX+//;				#get rid of the padded X's and a newline
			$decrypted .= "\n";				#add newline back in
			print OVEROUT $decrypted;			#output the decrypted data to a file
		} else {
			print OVEROUT $2;
		}
	} else {print "no match\n";}
}

sub padded {
	$padclone = $padding;
	while ($padding gt 0) {
		$random = int rand(255);
		
		$random = sprintf("%.2X\n", $random);

		if ($random =~ /(.)(.)/) {
			$random = pack("C*", map { $_ ? hex($_) :() } $1.$2);
		}
		print $random;
		$padding--;
	}
	$padding = $padclone;
}

sub bangforbuck {
	#Get fields of conf file here
	$arraysize = @headers;
	$index = 0;
	close IN;
	open IN, $inputfile or die "The file has to actually exist, try again $!\n";
	while (<IN>) {                                          #for each line of the input file
        	@fields = split /\s+/, $_;                      #make a space seperated array for line
        	#if the line exists, AND if it doesn't start with a #, AND if the first piece is an actual word
        	if ((@fields) && ($fields[0] !~ /^#/) && ($fields[1] =~ /\w+/)) {
                	$sizes[$index] = $fields[3];            #put file type in current index of @types array
			$headers[$index] = $fields[4];
			$footers[$index] = $fields[5];
                	$index++;                               #increment the index
        	}
	}

	#Now get the smallest file size stop
	$smallestsize = $sizes[0];
	$index = 0;
	while ($arraysize > $index) {
		if ($smallestsize > $sizes[$index]) {
			$smallestsize = $sizes[$index];
		}
		$index++;
	}

	#Now get how much data header info will be all together
	$index = 0;
	while ($arraysize > $index) {
		$headerssize .= $headers[$index];
		$index++;
	}
	$headerssize =~ s/\\x\w//g;
	@headers = "";
	@headers = split //, $headerssize;
	$headerssize = @headers;

	#Now get how much data footer info will be all together
	$index = 0;
	while (($arraysize > $index) && ($footers[$index])) {
		$footerssize .= $footers[$index];
		$index++;
	}
	if ($footerssize) {
	$footerssize =~ s/\\x\w//g;
	@footers = "";
	@footers = split //, $footerssize;
	$footerssize = @footers;
	} else {
		$footerssize = 0;
	}

	#Now get how much data is in the stego
	if (($osaur eq 1) && ($extract eq 0)) {
		if ($password ne "0XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") {
			@characters = split //, $crypted;
			$stegosize = @characters;
		} else {
			@characters = split //, $secret;
			$stegosize = @characters;
		}
	}

	$padding = $smallestsize - $headerssize - $footerssize - $stegosize;

}

sub finishhim {
#When did program finish
my $end = Time::HiRes::time();
$end = $end - $start;
print "100%\nFinished in ";
printf '%.2f', "$end";
print " seconds\n";
}
