#
#   OS390::Stdio - S/390 (MVS) extensions to Perl's stdio calls
#
#   Author:  Peter Prymmer  pvhp@best.com  pvhp@forte.com
#            adapted from Charles Bailey's VMS::Stdio V. 2.1
#   Revised:  13-Apr-1999
#   Previous: 31-Aug-1998
#

package OS390::Stdio;

require 5.005;
use vars qw( $VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS @ISA );
use Carp '&croak';
use DynaLoader ();
use Exporter ();
 
$VERSION = '0.004';
@ISA = qw( Exporter DynaLoader IO::File );

@EXPORT = qw( &KEY_FIRST &KEY_LAST &KEY_EQ &KEY_EQ_BWD 
              &KEY_GE &RBA_EQ &RBA_EQ_BWD
            );
#              &O_APPEND &O_CREAT &O_EXCL  &O_NDELAY &O_NOWAIT
#              &O_RDONLY &O_RDWR  &O_TRUNC &O_WRONLY 
@EXPORT_OK = qw( &flush 
                 &dsname_level  &dynalloc &dynfree
                 &forward &getname &get_dcb &mvsopen &mvswrite &pds_mem
                 &remove &rewind &resetpos &sysdsnr
                 &svc99 &tmpnam &vol_ser
                 &vsamdelrec &vsamlocate &vsamupdate
               );
%EXPORT_TAGS = ( CONSTANTS => [ qw( 
                                    &KEY_FIRST &KEY_LAST &KEY_EQ &KEY_EQ_BWD
                                    &KEY_GE &RBA_EQ &RBA_EQ_BWD
                                  ) ],
                 FUNCTIONS => [ qw( &flush &forward
                                    &getname &get_dcb &mvsopen &mvswrite 
                                    &pds_mem &remove &rewind &resetpos
                                    &sysdsnr &tmpnam 
                                    &vsamdelrec &vsamlocate &vsamupdate
                                    ) ], 
                 EXPERIMENTAL => [ qw( 
                                    &dsname_level &dynalloc &dynfree 
                                    &svc99 &vol_ser 
                                    ) ], 
               );

bootstrap OS390::Stdio $VERSION;

sub AUTOLOAD {
    my($constname) = $AUTOLOAD;
    $constname =~ s/.*:://;
    if ($constname =~ /^O_|^KEY_|^RBA_/) {
      my($val) = constant($constname);
      defined $val or croak("Unknown OS390::Stdio constant $constname");
      *$AUTOLOAD = sub { $val; }
    }
    else { # We don't know about it; hand off to IO::File
      require IO::File;

      *$AUTOLOAD = eval "sub { shift->IO::File::$constname(\@_) }";
      croak "Error autoloading IO::File::$constname: $@" if $@;
    }
    goto &$AUTOLOAD;
}

sub DESTROY { close($_[0]); }

# in case we ever use AutoLoader

1;

__END__

=head1 NAME

OS390::Stdio - S/390 standard I/O functions via POSIX/XPG extensions

=head1 SYNOPSIS

    use OS390::Stdio qw( &get_dcb &getname &pds_mem &sysdsnr
                         &mvsopen &mvswrite 
                         &flush &forward &rewind &resetpos
                         &remove &tmpnam 
                         &vsamdelrec &vsamlocate &vsamupdate
      # future dslist        &dsname_level &vol_ser 
      # future SVC 99        &dynalloc &dynfree &svc99 
                       );

    @dslist = dsname_level("FRED");
    $uniquename = tmpnam;
    $fh = mvsopen("//MY.STUFF","a recfm=F") or die $!;
    $name = getname($fh);
    print $fh "Hello, world!\n";
    flush($fh);
    rewind($fh);
    $line = <$fh>;
    undef $fh;  # closes data set
    $fh = mvsopen("dd:MYDD(MEM)", "recfm=U");
    sysread($fh,$data,128);
    close($fh);
    remove("dd:MYDD(MEM)");
    @members = pds_mem("//'SYS1.PARMLIB'");

=head1 DESCRIPTION

This package gives Perl scripts access via POSIX extensions to several
C stdio operations not available through Perl's CORE I/O functions.
The specific routines are described below.  These functions are
prototyped as unary operators, with the exception of C<mvsopen>
which takes two arguments, C<mvswrite> which takes three arguments,
C<dynalloc>, C<svc99> which take several arguments, and C<tmpnam> 
which takes none.

All of the routines are available for export, though none are
exported by default.  All of the constants used by C<vsamupdate>
to specify update options are exported by default.  The routines
are associated with the Exporter tag FUNCTIONS, the experimental
routines are associated with the Exporter tag EXPERIMENAL, and 
the constants are associated with the Exporter tag CONSTANTS, 
so you can more easily choose what you'd like to import:

    # import constants, but not functions
    use OS390::Stdio;  # same as use OS390::Stdio qw( :DEFAULT );
    # import functions, but not constants
    use OS390::Stdio qw( !:CONSTANTS :FUNCTIONS ); 
    # import both
    use OS390::Stdio qw( :CONSTANTS :FUNCTIONS ); 
    # import neither
    use OS390::Stdio ();
    # import everything
    use OS390::Stdio (:CONSTANTS :FUNCTIONS :EXPERIMENTAL );

Of course, you can also choose to import specific functions by
name, as usual.

This package C<ISA> IO::File, so that you can call L<IO::File>
methods on the handles returned by C<mvsopen>. 
The IO::File package is not initialized, however, until you
actually call a method that OS390::Stdio doesn't provide.  This
is done to save startup time for users who don't wish to use
the IO::File methods.

=over

In the following C<DSH> refers to a data set handle such as returned
by the C<mvsopen> routine.  For OS data sets C<NAME> refers to either a
double slashed name such as C<//BETTY.BAM>, or members such as
C<//BETTY.BAM(BAM)>; or to dd names such as C<dd:WILMA.PEBBLES>.

=item flush EXPR

This function causes the contents of stdio buffers for the specified
data set handle to be flushed.  If C<undef> is used as the argument to
C<flush>, all currently open data set handles are flushed.  Like the CRTL
fflush() routine, the buffering mode and file type can have an effect on
when output data is flushed.  C<flush> returns a true value if successful, 
and C<undef> if not.

=item forward DSH

C<forward> resets the current position of the specified data set handle
to the end of the data set.  It's really just a convenience
method equivalent in effect to C<fseek($fh,0L,SEEK_END)>.  It returns a
true value if successful, and C<undef> if it fails.  See also 
C<rewind> and C<resetpos>.

=item get_dcb DSH

This function retrieves the data control block information for the data set 
handle passed to it and returns it in a hash with keys approximated by the 
names of the elements of the C<fldata_t> struct (see the documentaton for 
the C<fldata()> C RTL routine for further information).

For example:

    use OS390::Stdio qw(mvsopen get_dcb);
    my $dshandle = mvsopen("//SEDIMENT.SLATE","r");
    my %slate_dcb = get_dcb($dshandle);
    close($dshandle);
    for (sort(keys(%slate_dcb))) {
        print "$_ = $slate_dcb{$_}\n";
    }

For the inverse (i.e. setting data set attributes) use appropriate 
arguments with either C<mvsopen>, C<dynalloc>, or C<svc99>.  For just 
the filename you can use C<getname> in place of C<get_dcb>.

=item getname DSH

The C<getname> function returns the data set filename associated
with a Perl I/O handle (via C<fldata()>).  If an error occurs, 
it returns C<undef>.

As an example consider:

    $dshandle = mvsopen("//FOO.BAR","r");
    $fullname = getname($dshandle);
    $hlq = $fullname;
    $hlq =~ s/\'([^\.]+)\..*/$1/;  # strip leading ' and trailing DS names
    print "The high level qualifier (HLQ) is $hlq\n";

or, assuming you are authorized to do so, in order to switch 
to a different HLQ:

    $mydshandle = mvsopen("//FOO.BAR","r");
    $myfullname = getname($mydshandle);
    $bobsuid = '214';
    setuid($bobsuid);
    $bobsdshandle = mvsopen("//FOO.BAR","r");
    $bobsfullname = getname($bobsdshandle);
    $bobshlq = $bobsfullname;
    $bobshlq =~ s/\'([^\.]+)\..*/$1/;
    print "Bob's pwname is ",(getpwuid($<))[0],"\n";
    print "Bob's high level qualifier (HLQ) is $bobshlq\n";

Note that both of these examples assume that UIDs map directly to 
profile prefixes, whereas they may not in general.  To obtain more
extensive information for a given data set handle see C<get_dcb>.

=item mvsopen NAME MODE

The C<mvsopen> function enables you to specify optional arguments
to the CRTL when opening a data set.  Its operation is similar to the 
built-in Perl C<open> function (see L<perlfunc> for a complete description),
but it will only open normal data sets; it cannot open pipes or duplicate
existing I/O handles.  The C<MODE> is typically taken from:

    qw(r w a r+ w+ a+ rb wb ab rt wt at rb+ wb+ ab+ rt+ wt+ at+)

Additional C<MODE> keyword parameters can be passed from:

    qw(acc= blksize= byteseek lrecl= recfm= type= asis password= noseek)

(See the B<C/C++ MVS Programming Guide> and the 
B<C/C++ MVS Library Reference> descriptions of C<fopen()> for detailed 
information on C<NAME> and C<MODE> arguments.)  If successful, C<mvsopen> 
returns a data set handle; if an error occurs, it returns C<undef>.

You can use the data set handle returned by C<mvsopen> just as you
would any other Perl file handle.  The class OS390::Stdio ISA
IO::File, so you can call IO::File methods using the handle
returned by C<mvsopen>.  However, C<use>ing OS390::Stdio does not
automatically C<use> IO::File; you must do so explicitly in
your program if you want to call IO::File methods.  This is
done to avoid the overhead of initializing the IO::File package
in programs which intend to use the handle returned by C<mvsopen>
as a normal Perl data set handle only.  When the scalar containing
a OS390::Stdio data set handle is overwritten, C<undef>d, or goes
out of scope, the associated data set is closed automatically.

=item mvswrite DSH EXPR LEN

The C<mvswrite> function provides access to stdio's C<fwrite()> function.
For example:

    use OS390::Stdio qw(mvsopen mvswrite);
    my $dshandle = mvsopen("//BED.ROCK","w+");
    my $fred,$data,$chrs_written;
    $fred = 100.00;
    $data = sprintf("Fred's salary is \$%3.2f",$fred);
    $chrs_written = mvswrite($dshandle,$data,length($data));
    close($dshandle);

=item pds_mem NAME

Returns a list of members (excluding ALIASes) for the named PDS directory.  
A list with a single C<undef> element is returned for PDS directories that 
have no members as well as for data set names that are not partitioned (in
the latter case a warning may appear on STDERR depending on how 
OS390::Stdio was compiled on your system).
For example:

    use OS390::Stdio qw(pds_mem);
    my @member_list = pds_mem("//'SLATE.PDS'");
    foreach my $mem (@member_list) {
        print "SLATE.PDS($mem)\n";
    }

=item remove NAME

This function deletes the data set (member) named in its argument, 
returning a true value if successful and C<undef> if not.  It differs 
from the CORE Perl function C<unlink> in that it does not try to
reset DS access if you are not authorized to delete the data set.

=item resetpos DSH

C<resetpos> resets the current position of the specified data set handle
to the current position.  This is useful for switching between input
and output at a given location.  It's really just a convenience
method equivalent in effect to C<fseek($fh,0L,SEEK_CUR)>.  It returns a
true value if successful, and C<undef> if it fails.  See also 
C<forward> and C<rewind> or Perl's builtin C<seek>.  (This was not 
called setpos to avoid namespace collision).

=item rewind DSH

C<rewind> resets the current position of the specified data set handle
to the beginning of the data set.  It's really just a convenience
method equivalent in effect to C<seek($fh,0,0)>.  It returns a
true value if successful, and C<undef> if it fails.  See also 
C<forward> and C<resetpos>.

=item sysdsnr NAME

Returns true if the named data set is available to C<fopen()> in "r" mode.
Note that perl's built in C<stat()> function as well as the various 
file test operators such as C<-r> do not work with OS data sets.

=item tmpnam

The C<tmpnam> function returns a unique string which can be used
as an HFS (POSIX) data set name when creating temporary storage.  
If, for some reason, it is unable to generate a name, it returns 
C<undef>.  Note that in order to ensure the creation of an OS data
set try using C<mvsopen> with a data set name of the form C<//&&name>.

=item vsamdelrec DSH

Deletes a record from a VSAM data set via the C RTL C<fdelrec()> routine.
You must C<seek> to the proper record before invoking vsamdelrec of course.
See also C<mvsopen>, C<vsamlocate>, and C<vsamupdate>.

=item vsamlocate DSH, key, key_len, options

Locates a record in a VSAM data set via the C RTL C<flocate()> routine.
See also C<mvsopen>, C<vsamdelrec>, and C<vsamupdate>.

=item vsamupdate DSH, record, length

Updates a record in a VSAM data set via the C RTL C<fupdate()> routine.
See also C<mvsopen>, C<vsamdelrec>, and C<vsamlocate>.

=back

The following functions are experimental:
V 0.001: Some are not currently working and either produce fatal 
errors or simply do not work as intended.

=over

=item dsname_level

This function returns a ds list for a given HLQ plus optional additional 
qualifiers.  It returns C<undef> if it encounters an error.  (The name 
was taken from the ISPF 3.4 panel entry).  See also C<vol_ser>.

V 0.003: This routine is not yet implemented and causes a fatal error.

Until this is working properly you can from perl code things such as:

    @listcat = `tso listcat`;

=item dynalloc 

Dynamically allocates a data set via the C RTL C<dynalloc()> routine.
See also C<svc99>.

V 0.003: This routine is not yet implemented and causes a fatal error.

=item dynfree 

Deallocates a data set via the C RTL C<dynfree()> routine.
See also C<svc99>.

V 0.003: This routine is not yet implemented and causes a fatal error.

=item svc99

This function provides access to the SVC 99 system service via a
C RTL C<svc99()> call.  See the B<C/C++ MVS Library Reference> for
information on C<svc99()>.

V 0.003: This routine is not yet implemented and causes a fatal error.

=item vol_ser 

Returns a dslist for a given volume serial input.   (The name was taken
from the ISPF 3.4 panel entry).

V 0.003: This routine is not yet implemented and causes a fatal error.

=back

=head1 REVISION

This document was last revised on 14-Apr-2001, for Perl 5.6.1.

13-Apr-1999, VERSION 0.003 for Perl 5.005_03.

31-Aug-1998, VERSION 0.002 for Perl 5.005_02.

=cut
