#!/usr/bin/perl -w

#
#Simple perl script to parse pastebin to alert on keywords of interest. 
#1)Install the the LWP and MIME perl modules
#2)Create two text files one called keywords.txt and tracker.txt
#2a)keywords.txt is where you need to enter keywords you wish to be alerted on, one per line.
#3)Edit the code below and enter your smtp server, from email address and to email address. 
#4)Cron it up and receive alerts in near real time
#

########################################################################
# Downloaded 1-29-13 from http://malc0de.com/tools/scripts/pastebin.txt
# by DA - I'm not the author, but I'm afraid that I've had my way with it.
# Changes:
#     Removed email code
#     Added random sleep to be considerate 
#     Added infinite loop to be inconsiderate
#     Added write the matching paste to a separate file (writeHitToFile)
#     Added writting matching expression to writeHitToFile
#     Moved read of regex to inside main loop - catch changes on the fly
#     Added write log of hits to HitList.txt
#     Added getopt and cleaned up a bit
########################################################################

$debugRequested = 0;
$delayInterval = 5;  # Default max delay between queries to web site
$keyWordsFileName = 'keywords.txt';
$fetchErrorCnt = 0;
$tryOneMoreTime = 0;
$webProxy = 0;

use LWP::Simple;
use LWP::UserAgent;

use Getopt::Long;

GetOptions ("h" => \$Help_Option, "d" => \$debugRequested, "w=s" => \$delayInterval, "k=s" => \$keyWordsFileName, 
	    "p=s" => \$webProxy );

if ($Help_Option){ &showHelp;}

my $ua = new LWP::UserAgent;
$ua->agent("Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1");

if ($webProxy){
    $ua->proxy('http', $webProxy);
}


my $tracking_file = 'tracker.txt';

while (1){

    # Load keywords.  Check the file each loop in case they've changed.
    open (MYFILE, $keyWordsFileName) or die "Couldn't open $keyWordsFileName: $!";
    @keywords = <MYFILE>;
    chomp(@keywords) ;
    $regex = join('|', @keywords);
    close MYFILE;

#Set the date for this run
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $datestring = sprintf("%4d-%02d-%02d",($year + 1900),($mon+1),$mday);
    my $dateTimeString = sprintf("%4d-%02d-%02d %02d:%02d",($year + 1900),($mon+1),$mday, $hour, $min);

    $dir = sprintf("%4d-%02d-%02d",($year + 1900),($mon+1), $mday);

    if ($webProxy){
	$ua->proxy('http', $webProxy);
    }
    my $req = new HTTP::Request GET => 'http://pastebin.com/archive';
    my $res = $ua->request($req);
    $pastebin = $res->content; 

    unless (defined $pastebin){
	die "Request from pastebin failed @ $dateTimeString: ($!)\n";
    }

    my @links = getlinks();
    $linkCount = $#links;

    &debugPrint ("\n");  # Just a stupid formatting thing
    print "Starting new batch at $dateTimeString. Save-to dir is $dir. Keywords file is $keyWordsFileName. regex is: $regex\n";
    &debugPrint ("size of \@links: $linkCount\n");
    if (@links) {
	$fetchErrorCnt = 0;
	$tryOneMoreTime = 0;
	foreach $line (@links){
	    &RandSleep ($delayInterval);
	    if  (checkurl($line) == 0){
		my $request = "http://pastebin.com/$line\n";
		my $link = $line;
		if ($webProxy){
		    $ua->proxy('http', $webProxy);
		}
		my $req = new HTTP::Request GET => "$request";	
		my $res = $ua->request($req);
		my $content = $res->content;
		my @data = $content;
		if ($debugRequested){
		    &debugPrint ("checking ($linkCount) - http://pastebin.com/$line ... ");
		    $linkCount--;
		}
		foreach $line (@data){
		    if ($content =~ m/\<textarea.*?\)\"\>(.*?)\<\/textarea\>/sgm){	
			@data = $1; 
			foreach $line (@data){
			    if ($line =~ m/($regex)/i){
				$Match = keyWordMatch ($line);
				storeurl($link);
				&debugPrint (" matched $Match ...");
				&writeHitToFile ($link, $line, $Match);
			    }
			}
			next;
		    }
		}
	    }		
	}
    }
    else {  # Sometimes the fetch fails.  Don't really know why, but we try a few more times before giving up
	unless ($tryOneMoreTime){ # unless we're on the very last try
	    print "fetch of links failed - can't say why (guess: $!). Sleeping for a minute ... \n";
	    sleep 60;
	    print "awake. Trying again\n";
	}
	if (++$fetchErrorCnt >= 10){
	    if ($tryOneMoreTime){
		print "That's it, waited an hour and still failing ... Giving up\n";
		exit;
	    }
	    print "10 failures in a row.  Sleeping for an hour and then trying ONE MORE TIME\n";
	    $tryOneMoreTime = 1;
	    sleep 3600;
	}
    }
}

sub getlinks{
    my @results;
    if (defined $pastebin) {
        @data = $pastebin;
        foreach $line (@data){
            while ($line =~ m/border\=\"0\"\s\/\>\<a\shref\=\"\/(.*?)"\>/g){
                my $url = $1;
        	push (@results, $url);        
	    }
	}
    }
    
    return @results;
}

sub storeurl {
    my $url = shift;
    open (FILE,">> $tracking_file") or die("cannot open $tracking_file");
    print FILE $url."\n";
    close FILE;
}

sub checkurl {
    my $url = shift;
    if (-e $tracking_file){
	open (FILE,"<$tracking_file") or die("cannot open $tracking_file for read");
    }
    else {
	return 0;  # File doesn't exist yet
    }
    foreach my $line ( <FILE> ) {
	if ( $line =~ m/$url/i ) {
	    &debugPrint ("detected repeat check of $url ");
	    return 1;
	}
    }
    return 0;
}

sub RandSleep{
    my $maxSleepTime = pop;
    my $sleepTime = int rand ($maxSleepTime + 1); # Need the +1 since we'll never hit maxSleepTime otherwise

    &debugPrint ("sleeping for $sleepTime ... ");
    sleep $sleepTime;
    &debugPrint ("awake!\n");
}

sub writeHitToFile{

    my $matchingExpression = pop;
    my $Contents = pop;
    my $url = pop;
    chomp ($url);

    unless (-e $dir){
	mkdir $dir or die "could not create directory $dir: $!\n";
    }

    if (-d $dir){
	open (HIT_FILE, ">$dir/$url") or die "could not open $dir/$url for write: $!\n";
	print HIT_FILE "http://pastebin.com/$url matched \"$matchingExpression\"\n" or die "print of url to $dir/$url failed: $!\n";
	print HIT_FILE $Contents or die "print of contents to $dir/$url failed: $!\n";
	close HIT_FILE;

	# Get the current time for the list file entry
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $datestring = sprintf("%4d-%02d-%02d %02d:%02d",($year + 1900),($mon+1),$mday, $hour, $min);

	open (HIT_LIST_FILE, ">>HitList.txt") or die "could not open HitList.txt for append: $!\n";
	print HIT_LIST_FILE "$dir/$url - http://pastebin.com/$url matched \"$matchingExpression\" at $datestring\n" or die "print of hit to HitList.txt failed: $!\n";
	close HIT_LIST_FILE;
    }
    else {
	die "$dir exists but is not a directory!\n";
    }
}

sub keyWordMatch{
    my $matchingLine = pop;

    foreach $check (@keywords){
	if ($matchingLine =~ m/$check/i){
	    return $check;
	}
    }
    return "No Match";
}

sub showHelp {
    print<<endHelp
$0: [-h] [-d] [-w <Max Wait Interval in seconds>][-p <http proxy>] [-k <Keywords File>]
-h: Show this help message
-d: Print debug output
-w <wait seconds>: Max wait in seconds between fetches.  Each fetch is delayed a random amount between 0 and this value. Default is 5 seconds.
-k <filename>: Name of file with keywords to monitor for.  Each line of the file is text or a perl regular expression. Default is \'keywords.txt\'
-p: Proxy through <http proxy>  (good for use with Zap or Burp)

Track progress via \"tail -f HitList.txt\"
endHelp
	;
    exit;  # We always exit after showing help
}

sub debugPrint{
    unless ($debugRequested){ return;}

    my $message = pop;
    $saveState=$|; $| = 1;  # Save whether print is buffered, and make unbuffered

    print $message;  # print the message

    $| = $saveState; # return print buffering to previous state
}
