/*
 * OS390::Stdio - MVS extensions to stdio routines 
 *
 * Author:   Peter Prymmer  pvhp@best.com
 * Version:  0.004
 * Revised:  14-Apr-2001
 * Version:  0.003
 * Revised:  10-Apr-1999
 * Version:  0.001
 * Revised:  31-Aug-1998
 *           (based on VMS::Stdio V. 2.1 by Charles Bailey)
 *
 * sync() is primarily POSIX, fsync() only takes an int fildes
 * hence OS390::Stdio::sync() cannot be implemented.
 *
 * stat() tends to deal only with POSIX file structures such as
 * struct stat in <sys/stat.h>, hence OS390::Stdio::stat() cannot be 
 * implemented (use sysdsnr() instead).
 *
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
/* allow POSIX extensions (?) */
#define _EXT 1
#include <sys/file.h>
#include <fcntl.h>
#include <stdio.h>
#include <dynit.h>
/* for pds_mem() */
#include <string.h>
#include <stdlib.h>

/*
 *  Note that FILENAME_MAX is defined in stdio.h to be
 *  either 1000 or 64, but this appears to not be quite 
 *  what we want since:
 *
 *  //A2345678.B2345678.C2345678.GxxxxVyy
 *  //A2345678.B2345678.C2345678.D2345678(12345678)
 *  12345678901234567890123456789012345678901234567
 *           1         2         3         4
 *
 * So let us go with:
 *
 */

#define MAXOSFILENAME 100

/*
 * The vsam flocate() function has constants
 *
 */
static bool
constant(name, pval)
char *name;
IV *pval;
{
/*
 *    if (strnNE(name, "O_", 2)) return FALSE;
 */
/*
    if ((strnNE(name, "O_", 2)) ||
        (strnNE(name, "KEY_", 4)) ||
        (strnNE(name, "RBA_", 4)))
         return FALSE;
 */

    if (strEQ(name, "KEY_FIRST"))
#ifdef __KEY_FIRST
	{ *pval = __KEY_FIRST; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "KEY_LAST"))
#ifdef __KEY_LAST
	{ *pval = __KEY_LAST; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "KEY_EQ"))
#ifdef __KEY_EQ
	{ *pval = __KEY_EQ; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "KEY_EQ_BWD"))
#ifdef __KEY_EQ_BWD
	{ *pval = __KEY_EQ_BWD; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "KEY_GE"))
#ifdef __KEY_GE
	{ *pval = __KEY_GE; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "RBA_EQ"))
#ifdef __RBA_EQ
	{ *pval = __RBA_EQ; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "RBA_EQ_BWD"))
#ifdef __RBA_EQ_BWD
	{ *pval = __RBA_EQ_BWD; return TRUE; }
#else
	return FALSE;
#endif

/*  The O_ constants are typically used with open() 
 *  [hence they may not be useful here]
 */
    if (strEQ(name, "O_APPEND"))
#ifdef O_APPEND
	{ *pval = O_APPEND; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_CREAT"))
#ifdef O_CREAT
	{ *pval = O_CREAT; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_EXCL"))
#ifdef O_EXCL
	{ *pval = O_EXCL; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_NDELAY"))
#ifdef O_NDELAY
	{ *pval = O_NDELAY; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_NOWAIT"))
#ifdef O_NOWAIT
	{ *pval = O_NOWAIT; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_RDONLY"))
#ifdef O_RDONLY
	{ *pval = O_RDONLY; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_RDWR"))
#ifdef O_RDWR
	{ *pval = O_RDWR; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_TRUNC"))
#ifdef O_TRUNC
	{ *pval = O_TRUNC; return TRUE; }
#else
	return FALSE;
#endif
    if (strEQ(name, "O_WRONLY"))
#ifdef O_WRONLY
	{ *pval = O_WRONLY; return TRUE; }
#else
	return FALSE;
#endif

    return FALSE;
}


static SV *
newFH(FILE *fp, char type) {
    SV *rv;
    GV **stashp, *gv = (GV *)NEWSV(0,0);
    HV *stash;
    IO *io;

    /* dTHR; */
    /* Find stash for VMS::Stdio.  We don't do this once at boot
     * to allow for possibility of threaded Perl with per-thread
     * symbol tables.  This code (through io = ...) is really
     * equivalent to gv_fetchpv("VMS::Stdio::__FH__",TRUE,SVt_PVIO),
     * with a little less overhead, and good exercise for me. :-) 
     */
    /*
     ** Well thanks Chuck :-) , er, s/VMS/OS390/g 8-)
     */
    stashp = (GV **)hv_fetch(PL_defstash,"OS390::",7,TRUE);
    if (!stashp || *stashp == (GV *)&PL_sv_undef) return Nullsv;
    if (!(stash = GvHV(*stashp))) stash = GvHV(*stashp) = newHV();
    stashp = (GV **)hv_fetch(GvHV(*stashp),"Stdio::",7,TRUE);
    if (!stashp || *stashp == (GV *)&PL_sv_undef) return Nullsv;
    if (!(stash = GvHV(*stashp))) stash = GvHV(*stashp) = newHV();

    /* Set up GV to point to IO, and then take reference */
    gv_init(gv,stash,"__FH__",6,0);
    io = GvIOp(gv) = newIO();
    IoIFP(io) = fp;
    if (type != '<') IoOFP(io) = fp;
    IoTYPE(io) = type;
    rv = newRV((SV *)gv);
    SvREFCNT_dec(gv);
    return sv_bless(rv,stash);
}

static void
h2dyn_t(HV *hip) {
    #ifdef _EXT
      __dyn_t ip;
    #else
      struct __dyn_t *ip;
    #endif
    /*
     * __dyn_t structure Table 16, pp 218-220 C/C++ MVS Library Reference
     */
    char * ddname;
    char * dsname;
    char sysout;
    char sysoutname[44];
    char * member;
    char status;
    char normdisp;
    char conddisp;
    char * unit;
    char * volser;
    char dsorg[7];   /* 'unknown' */
    char alcunit;
    int primary;
    int secondary;
    int dirblk;
    int avgblk;
    short recfm;
    short blksize;
    unsigned short lrecl;
    char volrefds[44];
    char dcbrefds[44];
    char dcbrefdd[9];
    unsigned char misc_flags;
    unsigned char CLOSE;
    unsigned char RELEASE;
    unsigned char CONTIG;
    unsigned char ROUND;
    unsigned char TERM;
    unsigned char DUMMY_DSN;
    unsigned char HOLDQ;
    unsigned char PERM;
    char password[8];
    char ** miscitems;
    short infocode;
    short errcode;
    char * storclass;
    char * stmgntclass;
    char * dataclass;
    char recorg;
    short keyoffset;
    short keylength;
    char * refdd;
    char * like;
    char dsntype;
    char * pathname;
    int pathopts;
    int pathmode;
    char pathndisp;
    char pathcdisp;
    #ifdef _EXT
    /*  s99rbx_t rbx; */
      struct s99rbx_t * rbx;
    #else
      struct s99rbx_t * rbx;
    #endif
    /*
     *
     */
}
/***************/
/*
 *******************************************************************
 ********* begin code borrowed from IBM's            ***************
 ********* B<C/C++ MVS Programming Guide>            ***************
 ********* Document number SCO9-2164-00              ***************
 ********* copyright 1995 IBM                        ***************
 ********* APPENDIX 1.8 Appendix H.                  ***************
 ********* which comes with a note that reads:       ***************
 ********* "This information is included to aid you  ***************
 *********  in such a task and is B<not> programming ***************
 *********  interface information."                  ***************
 ********* Among other possible problems it does not ***************
 ********* return ALIAS members (sigh).              ***************
 *********  - caveat scriptor.                       ***************
 *******************************************************************
 */

/*
 * NODE: a pointer to this structure is returned from the call to _pds_mem().
 * It is a linked list of character arrays - each array contains a member
 * name. Each next pointer points * to the next member, except the last
 * next member which points to NULL.
 */
#define NAMELEN 8      /* Length of an MVS member name */
typedef struct node {
                      struct node *next;
                      char name[NAMELEN+1];
                    } NODE, *NODE_PTR;

/*
 * NODE_PTR _pds_mem(const char *pds):
 *
 * pds must be a fully qualified pds name, for example,
 * ID.PDS.DATASET * returns a * pointer to a linked list of
 * nodes.  Each node contains a member of the * pds and a
 * pointer to the next node.  If no members exist, or the
 * pds is the name of a sequential file, the pointer
 * is NULL.
 *
 * Note:  Warnings will apear on STDERR if pds is the name 
 * of a sequential file.
 */
/*
 * RECORD:
 * each record of a pds will be read into one of these structures.
 * The first 2 bytes is the record length, which is put into 'count',
 * the remaining 254 bytes are put into rest.
 * Hence, each record is 256 bytes long.
 */
#define RECLEN  254
typedef struct {
    unsigned short int count;
    char rest[RECLEN];
} RECORD;

/*
 * static int gen_node(NODE_PTR *node, RECORD *rec, NODE_PTR *last_ptr);
 */
static char *pm_add_name(NODE_PTR *node, char *name, NODE_PTR *last_ptr);

/* the heart of the beast */
NODE_PTR _pds_mem(const char *pds) {
    FILE *fp;
    int bytes;
    NODE_PTR node, last_ptr;
    RECORD rec;
    int list_end;
    char *qual_pds;
    char filename[MAXOSFILENAME+1];
    fldata_t fileinfo;
    int rc;
    /*
     * initialize the linked list
     */
    node = NULL;
    last_ptr = NULL;
/*
 * Open the pds in binary read mode. The PDS directory will be read one
 * record at a time until either the end of the directory or end-of-file
 * is detected. Call up gen_node() with every record read, to add member
 * names to the linked list
 */
    fp = fopen(pds,"rb");
    if (fp == NULL) {
        fprintf(stderr,"fopen(%s,\"rb\") returned NULL.\n",pds);
        return((NODE_PTR)(-1));
    }
    rc = fldata(fp, filename, &fileinfo);
    if (rc != 0) {
        fprintf(stderr,"fldata() failed on %s.\n",pds);
        return((NODE_PTR)(-1));
    }
    if (fileinfo.__dsorgPO != 1) {
#ifndef NO_WARN_IF_NOT_PDS
        fprintf(stderr,
                "Data set %s [filename %s] does not appear to be a PDS.\n",
                pds,filename);
#endif
        return((NODE_PTR)(-1));
    }
    if (fileinfo.__dsorgPDSdir != 1) {
#ifndef NO_WARN_IF_NOT_PDS
        fprintf(stderr,
         "Data set %s [filename %s] does not appear to be a PDS directory.\n",
                pds, filename);
#endif
        return((NODE_PTR)(-1));
    }
    do {
        bytes = fread(&rec, 1, sizeof(rec), fp);
        if ((bytes != sizeof(rec)) && !feof(fp)) {
            perror("FREAD:");
            fprintf(stderr,"Failed in %s, line %d\n"
               "Expected to read %d bytes but read %d bytes\n",
                __FILE__,__LINE__,sizeof(rec), bytes);
#ifdef H_PERL
            croak("EFREAD\n");
#endif
            return((NODE_PTR)(-1));
        }
        list_end = gen_node(&node, &rec, &last_ptr);
    } while (!feof(fp) && !list_end);
    fclose(fp);
    return(node);
}
/*
 * GEN_NODE() processes the record passed. The main loop scans through the
 * record until it has read at least rec->count bytes, or a directory end
 * marker is detected.
 *
 * Each record has the form:
 *
 * +------------+------+------+------+------+----------------+
 * + # of bytes _Member_Member_......_Member_  Unused        +
 * + in record  _  1   _  2   _      _  n   _                +
 * +------------+------+------+------+------+----------------+
 *  _--count---__-----------------rest-----------------------_
 *  (Note that the number stored in count includes its own
 *   two bytes)
 *
 * And, each member has the form:
 *
 * +--------+-------+----+-----------------------------------+
 * + Member _TTR    _info_                                   +
 * + Name   _       _byte_  User Data TTRN's (halfwords)     +
 * + 8 bytes_3 bytes_    _                                   +
 * +--------+-------+----+-----------------------------------+
 */
#define TTRLEN 3      /* The TTR's are 3 bytes long */
/*
 * bit 0 of the info-byte is '1' if the member is an alias,
 * 0 otherwise. ALIAS_MASK is used to extract this information
 */
#define ALIAS_MASK ((unsigned int) 0x80)
/*
 * The number of user data half-words is in bits 3-7 of the info byte.
 * SKIP_MASK is used to extract this information.  Since this number is
 * in half-words, it needs to be double to obtain the number of bytes.
 */
#define SKIP_MASK ((unsigned int) 0x1F)

static int gen_node(NODE_PTR *node, RECORD *rec, NODE_PTR *last_ptr) {
    char *ptr, *name;
    int skip, count = 2;
    unsigned int info_byte, alias, ttrn;
    char ttr[TTRLEN];
    int list_end = 0;
    ptr = rec->rest;
    while(count < rec->count) {
        /*
         * 8 hex FF's mark the end of the directory
         */
        if (!memcmp(ptr,"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",NAMELEN)) {
            list_end = 1;
            break;
        }
        /* member name */
        name = ptr;
        ptr += NAMELEN;
        /* ttr */
        memcpy(ttr,ptr,TTRLEN);
        ptr += TTRLEN;
        /* info_byte */
        info_byte = (unsigned int) (*ptr);
        alias = info_byte & ALIAS_MASK;
        if (!alias) pm_add_name(node,name,last_ptr);
        skip = (info_byte & SKIP_MASK) * 2 + 1;
        ptr += skip;
        count += (TTRLEN + NAMELEN + skip);
    }
    return(list_end);
}
/*
 * ADD_NAME: Add a new member name to the linked node. The new member is
 * added to the end so that the original ordering is maintained.
 */
static char *pm_add_name(NODE_PTR *node, char *name, NODE_PTR *last_ptr) {
    NODE_PTR newnode;
    /*
     * malloc space for the new node
     */
    newnode = (NODE_PTR)malloc(sizeof(NODE));
    if (newnode == NULL) {
        fprintf(stderr,"malloc failed for %d bytes\n",sizeof(NODE));
#ifdef H_PERL
        croak("ENONMEM\n");
#endif
        return(NULL);
    }
    /* copy the name into the node and NULL terminate it */
    memcpy(newnode->name,name,NAMELEN);
    newnode->name[NAMELEN] = '\0';
    newnode->next = NULL;
    /*
     * add the new node to the linked list
     */
    if (*last_ptr != NULL) {
        (*last_ptr)->next = newnode;
        *last_ptr = newnode;
    }
    else {
        *node = newnode;
        *last_ptr = newnode;
    }
    return(newnode->name);
}

/*
 *******************************************************************
 ********* end code borrowed from IBM's              ***************
 ********* B<C/C++ MVS Programming Guide>            ***************
 *******************************************************************
 */
/***************/

MODULE = OS390::Stdio  PACKAGE = OS390::Stdio

void
constant(name)
	char * name
	PROTOTYPE: $
	CODE:
	IV i;
	if (constant(name, &i))
	    ST(0) = sv_2mortal(newSViv(i));
	else
	    ST(0) = &PL_sv_undef;

void
dsname_level(fp)
	FILE * fp
	PROTOTYPE: $
	CODE:
	    char vmsdef[8], es[8], sep;
	    unsigned long int retsts;
	    croak("dsname_level() not yet implemented.\n");
	    if (fsync(fileno(fp))) { ST(0) = &PL_sv_undef; }
	    else                   { clearerr(fp); ST(0) = &PL_sv_yes; }

char *
dynalloc(fp)
	FILE * fp
	PROTOTYPE: $
	CODE:
	    /* catalogs and VTOCS are tough :-} */
	    croak("dynalloc() not yet implemented.\n");
	    ST(0) = sv_newmortal();
	    ST(0) = &PL_sv_undef;

char *
dynfree(fp)
	FILE * fp
	PROTOTYPE: $
	CODE:
	    /* catalogs and VTOCS are tough :-} */
	    croak("dynfree() not yet implemented.\n");
	    ST(0) = sv_newmortal();
	    ST(0) = &PL_sv_undef;

void
flush(fp)
	FILE * fp
	PROTOTYPE: $
	CODE:
	    if (fflush(fp)) { ST(0) = &PL_sv_undef; }
	    else            { clearerr(fp); ST(0) = &PL_sv_yes; }

void
forward(fp)
	FILE * fp
	PROTOTYPE: $
	CODE:
	    ST(0) = fseek(fp, 0L, SEEK_END) ? &PL_sv_undef : &PL_sv_yes;

char *
get_dcb(fp)
	FILE *	fp
	PROTOTYPE: $
	CODE:
	    /*
	     * distillation of the fldata_t structure 
	     * Table 17, pg 310 C/C++ MVS Library Reference
	     */
	    char recfm[12] = ""; /* "F","V","U","S","Blk","ASA","M" */
	    char dsorg[42] = ""; /* "PO", "PDSmem","PDSdir","PS",  "Concat",
                                      "Mem","Hiper", "Temp",  "VSAM","HFS" */
	    char openmode[17] = ""; /* "TEXT","BINARY","RECORD" */
	    char modeflag[22] = ""; /* "APPEND","READ","UPDATE","WRITE" 
                                       + combos */
	    /* unsigned int reserve2; */
	    char device[11] = ""; /* "DISK","TERMINAL","PRINTER","TAPE",
	                             "TDQ", "DUMMY",   "OTHER",  "MEMORY",
                                     "MSGFILE","HFS", "HIPERSPACE" */
	    char vsamtype[10] = ""; /* "NOTVSAM","ESDS","KSDS","RRDS",
	                               "ESDS_PATH","KSDS_PATH" */
	    /* unsigned long reserve4; */
	    int i;
	    char filename[MAXOSFILENAME+1];
	    fldata_t fileinfo;
	    for (i=0; i<24; i++) {
	        ST(i) = sv_newmortal();
	    }
	    if ((fldata(fp,filename,&fileinfo)) == 0) {
                sv_setpv(ST(0),"filename");
                sv_setpv(ST(1),filename);
	        /* "F","V","U","S","Blk","ASA","M" */
	        if (fileinfo.__recfmF)
	            strcat(recfm,"F");
	        if (fileinfo.__recfmS)
	            strcat(recfm,"S");
	        if (fileinfo.__recfmU)
	            strcat(recfm,"U");
	        if (fileinfo.__recfmBlk)
	            strcat(recfm,"Blk");
	        if (fileinfo.__recfmASA)
	            strcat(recfm,"ASA");
                sv_setpv(ST(2),"recfm");
                sv_setpv(ST(3),recfm);
	        /* "PO", "PDSmem","PDSdir","PS",  "Concat",
                   "Mem","Hiper", "Temp",  "VSAM","HFS" */
	        if (fileinfo.__dsorgPO)
	            strcat(dsorg,"PO");
	        if (fileinfo.__dsorgPDSmem)
	            strcat(dsorg,"PDSmem");
	        if (fileinfo.__dsorgPDSdir)
	            strcat(dsorg,"PDSdir");
	        if (fileinfo.__dsorgPS)
	            strcat(dsorg,"PS");
	        if (fileinfo.__dsorgConcat)
	            strcat(dsorg,"Concat");
	        if (fileinfo.__dsorgMem)
	            strcat(dsorg,"Mem");
	        if (fileinfo.__dsorgHiper)
	            strcat(dsorg,"Hiper");
	        if (fileinfo.__dsorgTemp)
	            strcat(dsorg,"Temp");
	        if (fileinfo.__dsorgVSAM)
	            strcat(dsorg,"VSAM");
	        if (fileinfo.__dsorgHFS)
	            strcat(dsorg,"HFS");
                sv_setpv(ST(4),"dsorg");
                sv_setpv(ST(5),dsorg);
	        /* "TEXT","BINARY","RECORD" */
	        if (fileinfo.__openmode == __TEXT)
	            strcat(openmode,"TEXT");
	        if (fileinfo.__openmode == __BINARY)
	            strcat(openmode,"BINARY");
	        if (fileinfo.__openmode == __RECORD)
	            strcat(openmode,"RECORD");
                sv_setpv(ST(6),"openmode");
                sv_setpv(ST(7),openmode);
	        /* "APPEND","READ","UPDATE","WRITE" + combos */
	        if ((fileinfo.__modeflag & __APPEND) == __APPEND)
	            strcat(modeflag,"APPEND");
	        if ((fileinfo.__modeflag & __READ) == __READ)
	            strcat(modeflag,"READ");
	        if ((fileinfo.__modeflag & __UPDATE) == __UPDATE)
	            strcat(modeflag,"UPDATE");
	        if ((fileinfo.__modeflag & __WRITE) == __WRITE)
	            strcat(modeflag,"WRITE");
                sv_setpv(ST(8),"modeflag");
                sv_setpv(ST(9),modeflag);
	        /* "DISK","TERMINAL","PRINTER","TAPE",
	           "TDQ", "DUMMY",   "OTHER",  "MEMORY",
                   "MSGFILE","HFS", "HIPERSPACE" */
	        if (fileinfo.__device == __DISK)
	            strcat(device,"DISK");
	        if (fileinfo.__device == __TERMINAL)
	            strcat(device,"TERMINAL");
	        if (fileinfo.__device == __PRINTER)
	            strcat(device,"PRINTER");
	        if (fileinfo.__device == __TAPE)
	            strcat(device,"TAPE");
	        if (fileinfo.__device == __TDQ)
	            strcat(device,"TDQ");
	        if (fileinfo.__device == __DUMMY)
	            strcat(device,"DUMMY");
	        if (fileinfo.__device == __OTHER)
	            strcat(device,"OTHER");
	        if (fileinfo.__device == __MEMORY)
	            strcat(device,"MEMORY");
                sv_setpv(ST(10),"device");
                sv_setpv(ST(11),device);
	        /* unsigned long */
                sv_setpv(ST(12),"blksize");
                sv_setiv(ST(13),fileinfo.__blksize);
	        /* unsigned long */
                sv_setpv(ST(14),"maxreclen");
                sv_setiv(ST(15),fileinfo.__maxreclen);
	        /* "NOTVSAM","ESDS","KSDS","RRDS",
	           "ESDS_PATH","KSDS_PATH" */
	        if (fileinfo.__vsamtype == __NOTVSAM)
	            strcat(vsamtype,"NOTVSAM");
	        if (fileinfo.__vsamtype == __ESDS)
	            strcat(vsamtype,"ESDS");
	        if (fileinfo.__vsamtype == __KSDS)
	            strcat(vsamtype,"KSDS");
	        if (fileinfo.__vsamtype == __RRDS)
	            strcat(vsamtype,"RRDS");
	        if (fileinfo.__vsamtype == __ESDS_PATH)
	            strcat(vsamtype,"ESDS_PATH");
	        if (fileinfo.__vsamtype == __KSDS_PATH)
	            strcat(vsamtype,"KSDS_PATH");
                sv_setpv(ST(16),"vsamtype");
                sv_setpv(ST(17),vsamtype);
	        /* unsigned long */
                sv_setpv(ST(18),"vsamkeylen");
                sv_setiv(ST(19),fileinfo.__vsamkeylen);
	        /* unsigned long */
                sv_setpv(ST(20),"vsamRKP");
                sv_setiv(ST(21),fileinfo.__vsamRKP);
                sv_setpv(ST(22),"dsname");
                sv_setpv(ST(23),fileinfo.__dsname);
	        XSRETURN(24);
            }
            else {
	        ST(0) = &PL_sv_undef;
            }

char *
getname(fp)
	FILE * fp
	PROTOTYPE: $
	CODE:
	    char filename[MAXOSFILENAME+10];
	    fldata_t fileinfo;
	    ST(0) = sv_newmortal();
	    if ((fldata(fp,filename,&fileinfo)) == 0) {
                sv_setpv(ST(0),filename);
            }
            else {
	        ST(0) = &PL_sv_undef;
            }

void
mvsopen(name,mode)
	char * name
	char * mode
	PROTOTYPE: @
	CODE:
	    FILE * fp;
	    fp = fopen(name,mode);
	    if (fp != Nullfp) {
	      SV *fh = newFH(fp,(mode[1] ? '+' : (mode[0] == 'r' ? '<' : (mode[0] == 'a' ? 'a' : '>'))));
	      ST(0) = (fh ? sv_2mortal(fh) : &PL_sv_undef);
	    }
	    else { ST(0) = &PL_sv_undef; }

int
mvswrite(fp,buffer,count)
	FILE * fp
	char * buffer
	unsigned int count
	PROTOTYPE: @
	CODE:
	    /* use sizeof(char) til we get wchar_t's here && buffer */
	    RETVAL = fwrite((void *)buffer, sizeof(char), count, fp);
	OUTPUT:
	    RETVAL

char * 
pds_mem(pds)
	char * pds
	PROTOTYPE: $
	CODE:
	    NODE_PTR my_mem_orig;
	    NODE_PTR my_mem;
	    NODE_PTR next_mem;
	    char * member_name;
	    char * blank;
	    SV * tmp;
	    int i = 0;
	    my_mem = _pds_mem(pds);
	    my_mem_orig = my_mem;
	    next_mem = my_mem;
	    if (next_mem == (NODE_PTR)(-1)) {
	        ST(0) = sv_newmortal();
	        ST(0) = &PL_sv_undef;
	    }
	    else if (next_mem == NULL) {
	        ST(0) = sv_newmortal();
	        sv_setpv(ST(0),"");
	        XSRETURN(1);  
	    }
	    else {
                /* count the number of members we have seen */
	        while (next_mem != NULL) {
	            i++;
	            next_mem = my_mem->next;
	            my_mem = next_mem;
	        }
                /* extend perl return ST-ack by an appropriate amount */
		EXTEND(sp,i+1);
                /* reset pointers for second pass */
	        next_mem = my_mem_orig;
	        my_mem = my_mem_orig;
                /*
                 * put linked list names onto ST array, sans blank characters.
                 * Free the mallocs too.
                 */
	        while (next_mem != NULL) {
		    member_name = my_mem->name;
		    blank = strchr(member_name,' ');
                    if (blank != NULL)
		        *blank = '\0';
                    tmp = sv_2mortal(newSVpvn(member_name,strlen(member_name)));
	            PUSHs(tmp);
	            next_mem = my_mem->next;
	            free(my_mem);
	            my_mem = next_mem;
	        }
	        XSRETURN(i+1);
	    }

void
remove(name)
	char *name
	PROTOTYPE: $
	CODE:
	    ST(0) = remove(name) ? &PL_sv_undef : &PL_sv_yes;

void
resetpos(fp)
	FILE* fp
	PROTOTYPE: $
	CODE:
	    ST(0) = fseek(fp, 0L, SEEK_CUR) ? &PL_sv_undef : &PL_sv_yes;

void
rewind(fp)
	FILE* fp
	PROTOTYPE: $
	CODE:
	    /*
	     *  Unfortunately rewind() does not appear 
             *  to work on OE R2.5.  errno indicates only:
	     **  "EDC5129I No such file or directory."
	     * rewind(fp);
	     **   if (errno) printf("%s\n",strerror(errno));
	     * ST(0) = errno ? &PL_sv_undef : &PL_sv_yes;
	     *  hence we use fseek() instead.
             */
	    ST(0) = fseek(fp, 0L, SEEK_SET) ? &PL_sv_undef : &PL_sv_yes;

char *
svc99(parmstring)
	PROTOTYPE: $
	CODE:
	    struct __S99parms * parmstring;
	    unsigned char s99verb;
	    unsigned short s99flag1;
	    unsigned int s99flag2;
	    unsigned short s99error;
	    unsigned short s99info;
	    void * s99txtpp;
	    unsigned char *s99rbln;
	    void * s99s99x;
	    /* catalogs and VTOCS are tough :-} */
	    croak("svc99() not yet implemented.\n");
	    ST(0) = sv_newmortal();
	    ST(0) = &PL_sv_undef;

char *
sysdsnr(name)
	char *	name
	PROTOTYPE: $
	CODE:
	    FILE * fp;
	    fp = fopen(name,"r");
	    if (fp != Nullfp && (fclose(fp) == 0)) { ST(0) = &PL_sv_yes; }
	    else { ST(0) = &PL_sv_undef; }

char *
tmpnam()
	PROTOTYPE:
	CODE:
	    char fname[L_tmpnam];
	    ST(0) = sv_newmortal();
	    if (tmpnam(fname) != NULL) sv_setpv(ST(0),fname);

char *
vol_ser(fp)
	FILE *	fp
	PROTOTYPE: $
	CODE:
	    /* catalogs and VTOCS are tough :-} */
	    croak("vol_ser() not yet implemented.\n");
	    ST(0) = sv_newmortal();
	    ST(0) = &PL_sv_undef;

void
vsamdelrec(fp)
	FILE *	fp
	PROTOTYPE: $
	CODE:
	    int rc = fdelrec(fp);
	    ST(0) = rc ? &PL_sv_undef : &PL_sv_yes;

void
vsamlocate(fp, key, key_len, options)
	FILE *	fp
	void* key
	unsigned int key_len
	int options
	PROTOTYPE: @
	CODE:
	    int rc = flocate(fp, key, key_len, options);
	    ST(0) = rc ? &PL_sv_undef : &PL_sv_yes;

int
vsamupdate(fp,buffer,size)
	FILE *	fp
	void* buffer
	size_t size
	PROTOTYPE: @
	CODE:
	    RETVAL = fupdate(buffer, size, fp);
	OUTPUT:
	    RETVAL

