#
# Tests for OS390::Stdio
#

use strict;
use OS390::Stdio;
import OS390::Stdio qw(&dynalloc &dynfree &flush &forward &getname &get_dcb 
                       &mvsopen &mvswrite &pds_mem
                       &remove &resetpos &rewind &sysdsnr &tmpnam
                      );

my $DIAG = $ENV{'OS390_STDIO_DIAG'};
my $GORY = $ENV{'OS390_STDIO_GORY'};

print "1..76\n";
my $t = 1;
print "# OK how did the import go?\n" if $DIAG;
print +(defined(&dynalloc) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&dynfree) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&flush) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&forward) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&getname) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&get_dcb) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&mvsopen) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&mvswrite) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&pds_mem) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&remove) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&resetpos) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&rewind) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&sysdsnr) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&tmpnam) ? '' : 'not '), "ok $t\n"; $t++;
print "# we didn't yet ask for the unimplemented subs:\n" if $DIAG;
print +(!defined(&dsname_level) ? '' : 'not '), "ok $t\n"; $t++;
print +(!defined(&svc99) ? '' : 'not '), "ok $t\n"; $t++;
print +(!defined(&vol_ser) ? '' : 'not '), "ok $t\n"; $t++;
print +(!defined(&vsamdelrec) ? '' : 'not '), "ok $t\n"; $t++;
print +(!defined(&vsamlocate) ? '' : 'not '), "ok $t\n"; $t++;
print +(!defined(&vsamupdate) ? '' : 'not '), "ok $t\n"; $t++;
print "# and what became of those constants?\n" if $DIAG;
if ('A' eq 'B') 
{
print +(defined(&KEY_FIRST) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&KEY_LAST) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&KEY_EQ) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&KEY_EQ_BWD) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&KEY_GE) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&RBA_EQ) ? '' : 'not '), "ok $t\n"; $t++;
print +(defined(&RBA_EQ_BWD) ? '' : 'not '), "ok $t\n"; $t++;
}
else {
    print "# constant check turned off til next release\n" if $DIAG;
}

#
# e.g. //TEST3355.TEST3355
#
my $name = "//" . substr("TEST$$",0,8) . '.' . substr("TEST$$",0,8);
if (sysdsnr($name)) {
    die "name $name already exists, tests cannot proceed";
}
print "#$t filehandle returns from mvsopen for name=>$name<=\n" if $DIAG;
my $fh = mvsopen("$name","wt+");
print +($fh ? '' : 'not '), "ok $t\n"; $t++;

print "#$t tries to flush the \$fh\n" if $DIAG;
print +(flush($fh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t attempts to ->autoflush (from IO::File)\n" if $DIAG;
$fh->autoflush;  # Can we autoload autoflush from IO::File?  Do or die.
print "ok $t\n"; $t++;

print "#$t trys get_dcb(dsh)\n" if $DIAG;
my %dcb = get_dcb($fh);
                                           # e.g.
print +(defined(%dcb) ? '' : 'not '),"ok $t\n"; $t++;
                                           # hash %dcb ought to be there
print +(($dcb{'blksize'} > 0) ? '' : 'not '),"ok $t\n"; $t++;
                                           #blksize = 6144
print +(($dcb{'device'} eq "DISK") ? '' : 'not '),"ok $t\n"; $t++;
                                           #device = DISK
print +(defined($dcb{'dsname'}) ? '' : 'not '),"ok $t\n"; $t++;
                                           #dsname = PVHP.TEST3858.TEST3858
print +(($dcb{'dsorg'} eq "PS") ? '' : 'not '),"ok $t\n"; $t++;
                                           #dsorg = PS
print +(($dcb{'filename'} eq "'$dcb{'dsname'}'") ? '' : 'not '),"ok $t\n"; $t++;
                                           #filename = 'PVHP.TEST3858.TEST3858'
                                           # add single quotation marks
print +(($dcb{'maxreclen'} > 0) ? '' : 'not '),"ok $t\n"; $t++;
                                           #maxreclen = 1024
print +(($dcb{'modeflag'} eq "UPDATEWRITE") ? '' : 'not '),"ok $t\n"; $t++;
                                           #modeflag = UPDATEWRITE
print +(($dcb{'openmode'} eq "TEXT") ? '' : 'not '),"ok $t\n"; $t++;
                                           #openmode = TEXT
print +(($dcb{'recfm'} eq "Blk") ? '' : 'not '),"ok $t\n"; $t++;
                                           #recfm = Blk
print +(($dcb{'vsamkeylen'}==0) ? '' : 'not '),"ok $t\n"; $t++;
                                           #vsamkeylen = 0
print +(($dcb{'vsamtype'} eq "NOTVSAM") ? '' : 'not '),"ok $t\n"; $t++;
                                           #vsamtype = NOTVSAM
print +(($dcb{'vsamRKP'}==0) ? '' : 'not '),"ok $t\n"; $t++; 
                                           #vsamRKP = 0
if ($DIAG) { print "# dcb was:\n"; for(sort(keys(%dcb))) { print "## $_ = $dcb{$_}\n"; } }

print "#$t attempts to rewind\n" if $DIAG;
print +(rewind($fh) ? '' : 'not '),"ok $t\n"; $t++;

#
# Grab a scalar version of the system time for use as a string
#
my $date_str = scalar(localtime(time()));

print "#$t attempts to mvswrite $date_str\n" if $DIAG;
# let's pretend the extra character is C's '\0':
my $numwritten = mvswrite( $fh, $date_str, length($date_str)+1);
print +(($numwritten == (length($date_str)+1)) ? '' : 'not '),"ok $t\n"; $t++;
print "#$t numwritten=>$numwritten<=\n" if $DIAG;

print "#$t tries to flush the \$fh\n" if $DIAG;
print +(flush($fh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t attempts to rewind\n" if $DIAG;
print +(rewind($fh) ? '' : 'not '),"ok $t\n"; $t++;

my $line;
chop($line = <$fh>);
if ($DIAG) {
print "#$t attempts to compare the line read to =>$date_str<=\n";
}
if ($GORY) {
print <<"EOGORY0"
#$t attempts to compare the line read 
#=>$line<=
#to
#=>$date_str<=
EOGORY0
}
print +($line eq $date_str ? '' : 'not '), "ok $t\n"; $t++;

my $gotname = getname($fh);            # e.g. 'PVHP.TEST3355.TEST3355'
my $sans_slash = $name;                # e.g. //TEST3355.TEST3355
$sans_slash =~ s#\Q//\E##;             # e.g. TEST3355.TEST3355
my $hlq = (getpwuid($<))[0];           # e.g. PVHP
print "#$t gotname=>$gotname<= and 'hlq.sans_slash'=>'$hlq.$sans_slash'<=\n" 
  if $DIAG;
print +($gotname eq "'$hlq.$sans_slash'" ? '' : 'not '), "ok $t\n"; $t++;

my $slash_name = '//' . getname($fh);  # e.g. //'PVHP.TEST3355.TEST3355'
$slash_name =~ s/$hlq\.//;             # e.g. //'TEST3355.TEST3355'
$slash_name =~ s/\'//g;                # e.g. //TEST3355.TEST3355
print "#$t slash_name=>$slash_name<= and name=>$name<=\n" if $DIAG;
print +($slash_name eq "$name" ? '' : 'not '), "ok $t\n"; $t++;

print "#$t attempts to close the ds handle\n" if $DIAG;
print +(defined(close($fh)) ? '' : 'not '), "ok $t\n"; $t++;

#
# unlike other C RTLs we do not have an open() that can be used to access 
# data sets hence wrappered to provide a 'mvssysopen'.  So we just use the 
# regular mvsopen, that is, our wrapper around fopen() (and we don't 
# bother with a wrapper for freopen()).
#
print "#$t attempts to reopen $name for reading\n" if $DIAG;
my $mode = "r";
my $sfh = OS390::Stdio::mvsopen($name, $mode);
print +($sfh ? '' : 'not ($!) '), "ok $t\n"; $t++;

$line = '';
read($sfh,$line,24);             # e.g. Fri Sep 11 14:35:14 1998
if ($DIAG) {
print "#$t attempts to compare the line read to =>$date_str<=\n";
}
if ($GORY) {
print <<"EOGORY1"
#$t attempts to compare the line read 
#=>$line<=
#to
#=>$date_str<=
EOGORY1
}
print +($line eq $date_str ? '' : 'not '), "ok $t\n"; $t++;

undef $sfh;

print "# alas we can't stat a ds but should be able to sysdsnr it:\n" if $DIAG;
print "#$t sysdsnr(\"$name\") =>",sysdsnr("$name"),"<=\n" if $DIAG;
print +(sysdsnr("$name") ? '' : 'not '),"ok $t\n"; $t++;

print "#$t attempts to remove the data set used for testing\n" if $DIAG;
print +(remove("$name") ? '' : 'not '),"ok $t\n"; $t++;

print "#$t attempts to generate an HFS tmpnam\n" if $DIAG;
my $tmpnam = &OS390::Stdio::tmpnam();
print +($tmpnam ? '' : 'not '),"ok $t\n";
print "#$t tempnam=>$tmpnam<=\n" if $DIAG; $t++;

my $tmp_name = '//&&TST' . substr($$,0,3);
print "#$t attempts to open a temporary dataset: $tmp_name\n" if $DIAG;
my $tmp_dsh = mvsopen($tmp_name, "w+");
print +($tmp_dsh ? '' : 'not '),"ok $t\n";
print "#$t tmp_name=>$tmp_name<=\n" if $DIAG; $t++;

print "#$t finds name of temporary dataset\n" if $DIAG;
my $alloc_name = getname($tmp_dsh);
my $tmp_getname = "'$tmp_name'"; $tmp_getname =~ s#\Q//##;
print +(($alloc_name eq $tmp_getname) ? '' : 'not '),"ok $t\n";
print "#$t alloc_name=>$alloc_name<=\n" if $DIAG; $t++;

print "#$t mvswrite 3 records there\n" if $DIAG;
$numwritten = mvswrite($tmp_dsh,
                       $date_str."\n".$date_str."\r".$date_str."\n",
                       3*(length($date_str)+1));
print +(($numwritten == (3*(length($date_str)+1))) ? '' : 'not '),"ok $t\n";
print "#$t numwritten=>$numwritten<=\n" if $DIAG; $t++;

print "#$t flush write\n" if $DIAG;
print +(flush($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t rewind\n" if $DIAG;
print +(rewind($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t read\n" if $DIAG;
$line='';
chomp($line = <$tmp_dsh>);
print +($line eq $date_str ? '' : 'not '),"ok $t\n";
print "#$t line=>$line<=\n" if $GORY; $t++;

print "#$t checking list context: date_str . linefeed x 2\n" if $DIAG;
my @lines = <$tmp_dsh>;
print +(join('',@lines) eq "$date_str\n" x 2 ? '' : 'not '),"ok $t\n"; $t++;
print "#lines=>\n",map{ "## $_"} @lines,"<=\n" if $DIAG;

print "#$t rewind\n" if $DIAG;
print +(rewind($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

$line='';
chomp($line = <$tmp_dsh>);
print +($line eq $date_str ? '' : 'not '),"ok $t\n";
print "#$t line=>$line<=\n" if $GORY; $t++;

print "#$t resetpos\n" if $DIAG;
print +(resetpos($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

#
# Grab a new scalar version of the system time for use as a string
#
my $new_date_str = scalar(localtime(time()));
if ($new_date_str eq $date_str) {
    $new_date_str = reverse($new_date_str);
}

print "#$t mvswrite one record there\n" if $DIAG;
$numwritten = mvswrite($tmp_dsh,$new_date_str,length($new_date_str));
print +(($numwritten == length($new_date_str) ) ? '' : 'not '),"ok $t\n";
print "#$t numwritten=>$numwritten<=\n" if $DIAG; $t++;

print "#$t flush write\n" if $DIAG;
print +(flush($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

# we've read a line, resetpos'ed then mvswrote over 2nd line hence
# there should be two lines on a read:
@lines = ();
@lines = <$tmp_dsh>;
print "#$t number of lines -1 in dataset from here =>$#lines<=\n" if $DIAG;
print +(($#lines == 1 ) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t rewind\n" if $DIAG;
print +(rewind($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t forward\n" if $DIAG;
print +(forward($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t mvswrite one record there\n" if $DIAG;
$numwritten = mvswrite($tmp_dsh,$new_date_str,length($new_date_str));
print +(($numwritten == length($new_date_str) ) ? '' : 'not '),"ok $t\n";
print "#$t numwritten=>$numwritten<=\n" if $DIAG; $t++;

print "#$t flush write\n" if $DIAG;
print +(flush($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t rewind\n" if $DIAG;
print +(rewind($tmp_dsh) ? '' : 'not '),"ok $t\n"; $t++;

@lines = ();
@lines = <$tmp_dsh>;
print "#$t check number of lines -1 in whole dataset =>$#lines<=\n" if $DIAG;
print +(($#lines == 3 ) ? '' : 'not '),"ok $t\n"; $t++;
print "# lines =>\n",map {"## $_"} @lines,"<=\n" if $DIAG;

print "#$t closes (and deallocates) temp dataset\n" if $DIAG;
close($tmp_dsh);
print +($! ? '' : 'not ($1)'),"ok $t\n"; $t++;

# check to be sure it is gone
print "#$t after closing sysdsnr ing =>$alloc_name<=\n" if $DIAG;
print +(sysdsnr("$alloc_name") ? 'not ' : ''),"ok $t\n"; $t++;

##########################
print "#$t attempts to dynalloc a temporary PDS: $gotname\n" if $DIAG;
my $tmp_dynhsh = {( 
                    ddname  => "MYDD",          # //MYDD  DD
                    dsname  => "$gotname",      # //  DSN=$gotname,
                    status  =>  0x04,           # //  DISP=(NEW,
                    normdisp => 0x02,           # //        CATLG,
#                    normdisp => 0x04,           # //        DELETE,
#                    conddisp => 0x04,           # //        DELETE),
                    alcunit => '\x01',          # //  SPACE=(CYL,
                    primary => 1,               # //         1,
                    dirblk  => 1,               # //         1),
                    misc_flags => (0x02|0x08),  # //           RLSE,CONTIG),
                    recfm => 0x80 + 0x10,       # //   RECFM=FB,
                    lrecl => 80,                # //   LRECL=80,
                    blksize => 6080             # //   BLKSIZE=6080 
                 )};
print +(dynalloc($tmp_dynhsh) ? '' : 'not '),"ok $t\n"; $t++;

my $new_name = $gotname;
$new_name =~ s/'//g;
print "# attempt to write into \"//'$new_name(MEM1)'\"\n" if $DIAG;
my $tfh = OS390::Stdio::mvsopen("//'$new_name(MEM1)'", "w");
$numwritten = mvswrite($tfh,$new_date_str,length($new_date_str));
close($tfh);
print "# $numwritten were written into MEM1\n" if $DIAG;
print "# attempt to write into \"//'$new_name(MEM2)'\"\n" if $DIAG;
my $ufh  = OS390::Stdio::mvsopen("//'$new_name(MEM2)'","w");
my $numwritten2 = mvswrite($ufh,$new_date_str,length($new_date_str));
close($ufh);
print "# $numwritten2 were written into MEM2\n" if $DIAG;
print +((($numwritten + $numwritten2) == 2 * length($new_date_str) ) ? '' : 'not '),"ok $t\n"; $t++;
print "#$t attempts to list members with pds_mem(\"//$gotname\")\n" if $DIAG;
my @pds_mem = pds_mem("//$gotname");
my %my_pds = ();
my $pds_tot = 0;
for (sort(@pds_mem)) { $my_pds{$_}++; $pds_tot += $my_pds{$_}; }
print +(defined($my_pds{'MEM1'}) ? '' : 'not '),"ok $t\n"; $t++;
print "# members seen:\n", map {"## $_\n"} @pds_mem if $DIAG;
print "# members defined:\n", map {"## $_ = $my_pds{$_}\n"} sort(keys(%my_pds)) if $DIAG;
print "#$t makes sure list total: $pds_tot is equal to ",scalar(@pds_mem),"\n" if $DIAG;
print +((scalar(@pds_mem) == $pds_tot) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t attempts to dynfree a temporary PDS: $gotname\n" if $DIAG;
print +(dynfree($tmp_dynhsh) ? '' : 'not '),"ok $t\n"; $t++;

print "#$t verify removal of the data set used for pds_mem,dyn* testing\n" if $DIAG;
print +(sysdsnr("$gotname") ? 'not ' : ''),"ok $t\n"; $t++;
##########################

print "#t at end =>$t<=\n" if $DIAG;

