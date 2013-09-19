#!/usr/bin/perl -w

# This program is a custom hack job to view the saved files from my
# custom hack job Pastebin scraper program. :-)
# 
# The format of the files is as follows: The first line of the file
# contains the full URL and what specific string was matched in the
# paste to result in it being saved.  The rest of the file is the
# contents of the saved paste.
# 
# E.G:
# $ head -10 2013-02-09/017Gy3yZ 
# http://pastebin.com/017Gy3yZ matched "password"
# [10:45:02] [INFO] LaunchFrame.main:161: FTBLaunch starting up (version 1.2.2)
# [10:45:02] [INFO] LaunchFrame.main:162: Java version: 1.6.0_38
# [10:45:02] [INFO] LaunchFrame.main:163: Java vendor: Sun Microsystems Inc.
# [10:45:02] [INFO] LaunchFrame.main:164: Java home: C:\Program Files\Java\jre6
# [...]
#
# So, foreach file in the argv, we look at the first line.  The first
# line describes the primary match that was identified by the Pastebin
# scraper.  After we collected all the matches, we list each of the
# matched strings found (from the first line of each file) and a
# count.  The user will then be prompted to select one "match", and
# will then have the option to view any of the files which correspond
# to the match.
#
# The -m option shortcuts the collection process and just presents
# files which match the -m options.
#
# Timestamp
#
# The -n (show new files) and the -w (write timestamp) options control
# the ability to only view "new" files.  New files are files which
# were created after a previously established timestamp.  The
# timestamp is stored in a file, and is established either via the -w
# option, or via the 'w' command while viewing files via the -s
# option.
#
# De-Escape character entities
#
# It's very common for pastebin files to utilize the HTML character
# entities (e.g. &lt; for '<').  The -e option filters out a small
# subset of these for readability
#
########################################

use Getopt::Long;

$DEBUG = 0;
$debugFileName = 'DEBUG.txt';
$choiceCount = 40;   # Default on how many choices to give
$lineLength = 80;    # Default to chop line length
$viewOnlyNewFiles = 0;  # Flag: only look at files created since timestamp
$showMatchingLine = 0; # Flag, show first matching line instead of first line in file
$timeFileName = 'lastCheck';  # Where to write timestamp
$lastTimeChecked = 0;

GetOptions ("h" => \$Help_Option, "m=s" => \$matchStringArg, "d" => \$DEBUG, "e" => \$deEscape, 
	    "n" => \$viewOnlyNewFiles, "w" => \$setNewFilesDate, "l" => \$showMatchingLine,
	    "p=s" => \$choiceCount);

if ($Help_Option){ &showHelp;}

if ($DEBUG){  # Open debug output file
    open DEBUG_FILE, ">$debugFileName" or die "open of $debugFileName failed: $!";
    $debugDate = `date`;
    print DEBUG_FILE "Starting debug output to $debugFileName at $debugDate";
    print DEBUG_FILE "Command Line Options:\n";
    if (defined $matchStringArg){
	print DEBUG_FILE "   matchStringArg = $matchStringArg\n";
    }
    if (defined $DEBUG){
	print DEBUG_FILE "   DEBUG = $DEBUG\n";
    }
    if (defined $deEscape){
	print DEBUG_FILE "   deEscape = $deEscape\n";
    }
    if (defined $viewOnlyNewFiles){
	print DEBUG_FILE "   viewOnlyNewFiles = $viewOnlyNewFiles\n";
    }
    if (defined $setNewFilesDate){
	print DEBUG_FILE "   setNewFilesDate = $setNewFilesDate\n";
    }
    if (defined $showMatchingLine){
	print DEBUG_FILE "   showMatchingLine = $showMatchingLine\n";
    }
    if (defined $choiceCount){
	print DEBUG_FILE "   choiceCount = $choiceCount\n";
    }
}

while (1){ # We keep looping through choices until we exit

    # clear out results from last run (if there was one)
    foreach $key (keys %matchCount){delete $matchCount{$key};}  
    foreach $key (keys %matchList){ delete $matchList{$key};} 
    $totalMatches = 0;
    $matchedFileCount = 0;

    # Handle -n option
    if ($viewOnlyNewFiles){
	$now = time;
	if (-e $timeFileName){   # If there's timestamp file, use it
	    open TIME, "<$timeFileName" or die "open of $timeFileName for read failed: $!";
	    $lastTimeChecked = <TIME>;
	    close TIME;
	}
	else {  # Otherwise force user to create a timestamp file
	    unless ($setNewFilesDate){
		print "-n option invalid since timestamp file \"$timeFileName\" was not found.  Use -w option to establish. Exiting.\n";
		exit;
	    }
	}
    }

    # Handle -w option
    if ($setNewFilesDate){   # user has said to create or update timestamp file
	$now = time;
	open TIME, ">$timeFileName" or die "open of $timeFileName for write failed: $!";
	print TIME $now;
	close TIME;
    }

    if ($matchStringArg){
	# User used -m option to select a custom match, skip first
	# loop through files since we know what to match

	if ($DEBUG){print DEBUG_FILE "user selected -m: matchStringArg = $matchStringArg\n";}

	$matchString = $matchStringArg;
    }
    else {
	
    # Cycle through all the files, look at the first line (contains
    # the match string from PasteScrape).  We'll use this to present
    # the user with a list of matches to select from.

	$totalMatches = 0;

	foreach $fileName (@ARGV){  # we go through each of the files specified by user
	    unless (-e $fileName){   # Just in case of a user typo or something
		print "Couldn't find $fileName, exiting\n";
		exit;
	    }

	    if ($DEBUG){ print DEBUG_FILE "in file examination loop: fileName = $fileName\n";}

	    if ($viewOnlyNewFiles){  # user only wants to see new files. Compare this file to timestamp
		@fileStats = stat ($fileName);
		if ($DEBUG){print DEBUG_FILE "file access date = $fileStats[9], lastTimeChecked = $lastTimeChecked\n";}
		if ($fileStats[9] < $lastTimeChecked){
		    next;
		}
	    }

	    # Now, open the file and examine the first line 
	    open FILE, "<$fileName" or die "open of $fileName failed: $!";
	    $firstLine = <FILE>;
#	    if ($firstLine eq ''){die "attempt to read $fileName for -s failed: $!";}
	    unless (defined $firstLine){next;}

	    $firstLine =~ /.+matched\s+\"(.+)\"/;
	    if ($DEBUG){print DEBUG_FILE "  matched = $1\n";}

	    # Keep track of how many files "match" each match string
	    $matchCount{$1}++;
	    $totalMatches++;

	    close FILE;
	} # foreach $fileName ...

	# Now that we've looked at each of the requests files, show
	# them to user and see which "match" is of interest
	unless ($DEBUG){system ('/usr/bin/clear');}
	print "$totalMatches total primary matches (as identified by PasteScrape):\n";
	$matchIndex = 0;
	foreach $match (sort byCount keys %matchCount){
	    $matchArray[$matchIndex] = $match;
	    print "$matchIndex --> ($matchCount{$match}) $match\n";
	    $matchIndex++;
	}
	print "$matchIndex --> Provide a custom search string\n";

	print "Select a matching expression to review (\#, \"w\" or \"q\" to quit): ";
	$inLine = <STDIN>;
	if ($inLine =~ /q/i){  # User requested quit
	    exit;
	}

	if ($inLine =~ /w/i){  # User requested we reset the timestamp
	    $now = time;
	    open TIME, ">$timeFileName" or die "open of $timeFileName for write failed: $!";
	    print TIME $now;
	    close TIME;

	    print "New timestamp written, exiting\n";
	    exit;
	}

	# So now, the user should have selected which match string to
	# review the files which match.  User selects the number of
	# the match string
	chomp ($inLine);
	unless ($inLine =~ /^\s*\d+\s*$/){   # test for a simple digit input
	    unless ($inLine =~ /^\s*$/) {    # exit on empty line, but no error msg
		print "Didn't recognize \"$inLine\" as a valid choice (must be an integer.) Exiting\n";
	    }
	    exit;
	}
	$matchSelection = int ($inLine);

	if ($DEBUG){print DEBUG_FILE "matchSelecton = $matchSelection\n";}

	unless (($matchSelection >= 0) and ($matchSelection <= ($matchIndex))){ # range check user selection
	    print "\"$matchSelection\" isn\'t a valid selection. Exiting\n";
	    exit;
	}

	if ($matchSelection == $matchIndex){  # User selected custom search string
	    print "Search string: ";
	    $matchString = <STDIN>;
	    chomp ($matchString);
	    if ($DEBUG){ print DEBUG_FILE "matchString = $matchString (user provided)\n";}
	}
	else {
	    $matchString = $matchArray[$matchSelection];    # determine the selected match string from list
	    if ($DEBUG){ print DEBUG_FILE "matchString = matchArray[$matchSelection] ($matchArray[$matchSelection])\n";}
	}
    }  # else (present potential matches to user)


    # We've shown the user all the match strings and/or the user has
    # told us which one to look at.  Now cycle through all the files
    # again, and if the first line (or any line, with -l) matches the
    # user selected, add it to the list to present the user.  There
    # may be hundreds of matches, so we need to present them in
    # batches.

FILE_LOOP:
    foreach $fileName (@ARGV){

	if ($DEBUG){ print DEBUG_FILE "fileName = $fileName\n";}

	if ($viewOnlyNewFiles){ # as before, user may only want to consider "new" files.
	    @fileStats = stat ($fileName);
	    if ($DEBUG){print DEBUG_FILE "file access date = $fileStats[9], lastTimeChecked = $lastTimeChecked\n";}
	    if ($fileStats[9] < $lastTimeChecked){
		next;  # skip files which are not "new"
	    }
	}

	open FILE, "<$fileName" or die "open of $fileName failed: $!";
	$firstLine = <FILE> ;  # contains the "match" string
	unless (defined $firstLine){next;}  # skip if empty
	if ($firstLine !~ /matched/){next;} # File is not in right format, skip it
	if ($showMatchingLine){  # User wants to see the matching line, not the first line in the file
	    if ($DEBUG){ print DEBUG_FILE "Searching all of $fileName for $matchString\n";}
	    while ($inLine = <FILE>){
		if ($inLine =~ /$matchString/i){
		    if ($DEBUG){ print DEBUG_FILE "Found a match for $matchString in $fileName\n";}
		    chomp($inLine);
		    $matchList{$fileName} = $inLine;
		    $matchedFileCount++;
		    close FILE;
		    next FILE_LOOP;
		}
	    }
	}
	else {
	    $secondLine = <FILE>;  # this will give user a hint as to contents of the file
	    unless (defined $secondLine){next;}  # skip if empty
	    chomp($secondLine);
	    close FILE;
	    $firstLine =~ /.+matched\s+\"(.+)\"/i;  # Does this file match the requested "match" strong
	    unless (defined $1){
		if ($DEBUG){print DEBUG_FILE "  --> failed to find match in \"$firstLine\"\n";}
		next;
	    }
	    if ($DEBUG){print DEBUG_FILE "  matched = $1\n";}
	    if ($matchString eq $1){   # we have a match.  Set the second line aside to show user
		$matchList{$fileName} = $secondLine;
		$matchedFileCount++;
	    }
	}
    }

    if ($DEBUG){
	foreach $matchFile (keys %matchList){
	    print DEBUG_FILE "$matchFile --> $matchList{$matchFile}";
	}
    }

# We've collected the names of all the files which have the "match"
# string in their first line.  We've also collected the second line
# (or first matching line) from each of these files.  The second line
# will often allow the user to determine what type of contents are in
# a file.  Present the list to the user and let her select which ones
# to view using the unix "less" command.  User input is the # of the
# entry to show, user can select multiple entries.

    unless ($DEBUG){system ('/usr/bin/clear');}
    print "Found $matchedFileCount ";

    if ($matchedFileCount == 0){  # ghads, I hate special cases  :-)
	print "matches\n";
    }

    $pickID = 0;
    $totalMatchCount = keys %matchList;
    $matchesShownCount = $choiceCount;
    foreach $matchFile ( keys %matchList){
	if ($pickID == 0){   # print at top of the screen listing next set of matches
	    $matchesLeft = $totalMatchCount - $matchesShownCount;
	    if ($showMatchingLine){
		if ($matchesLeft <= 0){
		    print "files which contain \"$matchString\" ...\n";
		}
		else {
		    print "files which contain \"$matchString\". $matchesLeft are left after this group ...\n";
		}
	    }
	    else {
		if ($matchesLeft <= 0){
		    print "files identified by PasteScrape as containing \"$matchString\" ...\n";
		}
		else {
		    print "files identified by PasteScrape as containing \"$matchString\". $matchesLeft are left after this group ...\n";
		}
	    }
	}
	$pickList[$pickID] = $matchFile;
	$escapedString = &filterEscapeString($matchList{$matchFile});
	print "$pickID ($matchFile) >> $escapedString\n";   # print each file's info for user
	$matchesShownCount++;
	$pickID++;

	# We only show choiceCount files at a time, to avoid scrolling
	# choices off the screen.

	if ($pickID >= $choiceCount){  # We've completed a batch.  Now see which ones the user wants to see
	    print "\nSelect matches to review (separate by \",\" or \".\", \<cr\> for next group, \"\*\", \"q\" to quit): ";
	    $inLine = <STDIN>;
	    if (length ($inLine) > 1){
		if ($inLine =~ /q/i){  # User requested quit
		    exit;
		}

		if ($inLine =~ /\*/){ # "wildcard" ... user wants to view them all
		    $inLine = "0";
		    foreach $i (1 .. $pickID - 1){  # yeah, it's a hack - build up a fake user input
			$inLine .= ", $i";
		    }
		}

		@selected = split (/,|\./,$inLine);  # parse user input.
		foreach $selectedID (@selected){
		    $selectedID =~ s/\s+//g;  # lose extraneous spaces in input

		    if ($DEBUG){ print DEBUG_FILE "select = $selectedID, ";}

		    if (($selectedID !~ /^\d+$/) or ($selectedID > $pickID - 1) or ($selectedID < 0)){ 
			next;    # range check user input, skip if out of range
		    }

		    $selectedFileName = $pickList[$selectedID];
		    if ($deEscape){  # If user has requested filtering, do it now
			$selectedFileName = &filterEscapeFile($selectedFileName);
		    }
		    system ("/usr/bin/less -i -p \'$matchString\' $selectedFileName"); # show file to user
		}
	    }

	    # Prepare for next "batch" of files to consider
	    $pickID = 0;
	    @selected = '';
	    unless ($DEBUG){system ('/usr/bin/clear');}
	}
    }

    if ($pickID != 0){
	print "\nSelect matches to review (separate by \",\" or \".\", \<cr\> for next set, \"\*\" for all, \"q\" to quit): ";
	$inLine = <STDIN>;
	if (length ($inLine) > 1){
	    if ($inLine =~ /q/i){  # User requested quit
		exit;
	    }

	    if ($inLine =~ /\*/){ # user wants to view them all
		$inLine = "0";
		if ($DEBUG) {print DEBUG_FILE "starting in wildcard(2): inLine = $inLine\n";}
		foreach $i (1 .. $pickID - 1){
		    if ($DEBUG) {print DEBUG_FILE "in wildcard loop(2): i = $i, inLine = $inLine\n";}
		    $inLine .= ", $i";
		}
	    }


	    @selected = split (/,|\./,$inLine);
	    foreach $selectedID (@selected){
		$selectedID =~ s/\s+//g;
		if (($selectedID !~ /^\d+$/) or ($selectedID > $pickID - 1) or ($selectedID < 0)){ next;}
		$selectedFileName = $pickList[$selectedID];
		if ($deEscape){
		    $selectedFileName = &filterEscapeFile($selectedFileName);
		}
		system ("/usr/bin/less -i -p \'$matchString\' $selectedFileName");
	    }
	}
    }

    if ($matchStringArg){  # We only loop once if user invoked with -m
	if ($DEBUG) {print DEBUG_FILE "done with -m, exiting\n";}
	exit;
    }
}

if ($DEBUG) {print DEBUG_FILE "Fell into exit outside while(1) loop!!!!\n";}
print "unexpected exit!\n";
exit;


sub filterEscapeFile{
    my $fileToFilter = pop;
    my $tmpCopyFile = '/tmp/LogViewTmp';
    my $inLine = '';
    my $outLine = '';

    open IN_FILE, "<$fileToFilter" or die "open of IN_FILE ($fileToFilter) failed: $!";

    open OUT_FILE, ">$tmpCopyFile" or die "open of OUT_FILE ($tmpCopyFile) failed: $!";

    print OUT_FILE "Original unfiltered file: $fileToFilter --> " or die "write of Original Filename to to $tmpCopyFile failed: $!";
    
    while ($inLine = <IN_FILE>){
	$inLine =~ s/\&quot;/\'/g;
	$inLine =~ s/\&amp;/\&/g;
	$inLine =~ s/\&lt;/\</g;
	$inLine =~ s/\&gt;/\>/g;
	$inLine =~ s/\&ldquo;/\"/g;
	$inLine =~ s/\&rdquo;/\"/g;
	$inLine =~ s/\&lsquo;/\'/g;
	$inLine =~ s/\&rsquo;/\'/g;
	$inLine =~ s/\&hellip;/\.\.\./g;

	$inLine =~ s/\e/<ESC>/g;

	print OUT_FILE $inLine or die "write to $tmpCopyFile failed: $!";
    }

    close IN_FILE;
    close OUT_FILE;
    return $tmpCopyFile;
}

sub filterEscapeString{
    my $stringToFilter = pop;

    $stringToFilter =~ s/\&quot;/\'/g;
    $stringToFilter =~ s/\&amp;/\&/g;
    $stringToFilter =~ s/\&lt;/\</g;
    $stringToFilter =~ s/\&gt;/\>/g;
    $stringToFilter =~ s/\&ldquo;/\"/g;
    $stringToFilter =~ s/\&rdquo;/\"/g;
    $stringToFilter =~ s/\&lsquo;/\'/g;
    $stringToFilter =~ s/\&rsquo;/\'/g;
    $stringToFilter =~ s/\&hellip;/\.\.\./g;

    if (length ($stringToFilter) > $lineLength){
	$stringToFilter = substr ($stringToFilter, 0, $lineLength);
    }

    $stringToFilter =~ s/\e/<ESC>/g;


    return $stringToFilter;
}

sub byCount {
    return $matchCount{$a} <=> $matchCount{$b};
}

sub showHelp {
    print<<endHelp

Use this program to review files saved by the PasteScrape program.
Files are reviewed using the \"less\" program.

$0: [-h] [-d] [-e] [-n] [-w] [-l] [-m <matchstring>]  <files to view>
-h: Show this help message
-d: Save debug output to $debugFileName
-e: Convert common escape characters back to normal (e.g. \"\&lt\;\" to \"\<\")
-n: View only files created since last timestamp was saved to timestamp file
-w: Save current time into timestamp file
-l: When listing matches, show first match in file, not first line in file
-m: Only show files which contain <matchstring>
-p: Print <line-count> matches for second set of pages (default is 40)

Normally, there are two sets of pages shown.  The first page shows the
various matches which were identified by PasteScrape. It also shows
how many files PasteScrape saved for each match.  When you select a
match from this page, the second set of pages will provide a list of
all the files which contain this match along with a line from each
file to help you identify files of interest.  Those files you select
will then be shown to you via the "less" program.

Using the -m option skips the first page and takes you directly to the
second set of pages.  When combined with -l, the entire contents of
each file will be searched for <matchstring>, otherwise all matches
will be based on the primary match identified by PasteScrape.

The followng options will be available on the first page:
<\#>: Select the match to view by specifying its number
\"w\": Write the timestamp file and quite the program (see the -n option)
\"q\": To quit the program
You will also have the option to specify a custom search string or
regular expression

After selecting the number of a match to view (or if using -m), you
will be presented with a list of files which match your request.

By default, the first line of each matching file is shown (since this
will often identify the type of file).  With the -l option, the first
matching line in the file will be shown instead.  Please note that
since the -l option searches the entire file for matches, it may
identify more files to review than were identified by PasteScrape
(e.g. a file identified by PasteScrape as containing "Password" may
show up when you request matches for "Username", since it contains
both.)

When presented with a list of matches, the following commands are
available:
<\#>: Select matches to review (select by number and separate by \",\" or \".\")
\<cr\>: To move to the next page of matches (or back to the first page if done) 
\"\*\": To select all the files shown
\"q\": To quit the program

A common usage would be: $0 -n -e -l 2013-04-\*/\* 

endHelp
	;
    exit;  # We always exit after showing help
}
