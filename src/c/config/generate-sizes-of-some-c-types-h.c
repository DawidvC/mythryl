// generate-sizes-of-some-c-types-h.c
//
// This program generates the
//
//     src/c/o/sizes-of-some-c-types--autogenerated.h
//
// file, which is usable in both C and assembly files.

#include "../mythryl-config.h"

#include <stdlib.h>
#include <stdio.h>

#if HAVE_SYS_TYPES_H
    #include <sys/types.h>
#endif

#if HAVE_SYS_STAT_H
    #include <sys/stat.h>
#endif

#if HAVE_FCNTL_H
    #include <fcntl.h>
#endif

#include "header-file-autogeneration-stuff.h"

#if defined(SIZES_C_64_MYTHRYL_64)
#  error "64 bits not supported yet"
#else
#  define WORD_BYTESIZE	4
#endif
#  define POINTER_BYTESIZE	sizeof(char *)

static union {
    char	    bytes[sizeof(unsigned long)];
    unsigned long   l;
} U;



int  log_2 (int x) {				// Avoid conflicting with gcc log2 built-in fn.
    //
    int  i,     j;
    for (i = 1, j = 2;  j <= x;  i++, j += j)	continue;
    //
    return i-1;
}



int   main   (void)   {
    //
    char*       filename      = "sizes-of-some-c-types--autogenerated.h";
    char*       unique_string = "SIZES_OF_SOME_C_TYPES__AUTOGENERATED_h";
    char*       progname      = "src/c/config/generate-sizes-of-some-c-types-h.c";

    char*  i16  = NULL;
    char*  i32  = NULL;
    char*  i64  = NULL; 

    switch (sizeof(short)) {
    case 2: i16 = "short"; break;
    case 4: i32 = "short"; break;
    case 8: i64 = "short"; break;
    }

    switch (sizeof(int)) {
    case 2: i16 = "int"; break;
    case 4: i32 = "int"; break;
    case 8: i64 = "int"; break;
    }

    switch (sizeof(long)) {
    case 2: i16 = "long"; break;
    case 4: i32 = "long"; break;
    case 8: i64 = "long"; break;
    default:
	fprintf(stderr, "generate-sizes-of-some-c-types-h.c: Error -- no 32-bit integer type\n");
	exit (1);
    }

    if (i16 == NULL) {
	fprintf(stderr, "generate-sizes-of-some-c-types-h.c: Error -- no 16-bit integer type\n");
	exit (1);
    }
    if (i32 == NULL) {
	fprintf(stderr, "generate-sizes-of-some-c-types-h.c: Error -- no 32-bit integer type\n");
	exit (1);
    }
    #if (defined(SIZES_C_64_MYTHRYL_32) || defined(SIZES_C_64_MYTHRYL_64))
	if (i64 == NULL) {
	    fprintf(stderr, "generate-sizes-of-some-c-types-h.c: Error -- no 64-bit integer type\n");
	    exit (1);
	}
    #endif

    FILE* fd = start_generating_header_file( filename, unique_string, progname );				// start_generating_header_file		def in    src/c/config/start-and-finish-generating-header-file.c

    fprintf(fd, "#define WORD_BYTESIZE           %d\n", WORD_BYTESIZE);
    fprintf(fd, "#define POINTER_BYTESIZE           %d\n", POINTER_BYTESIZE);
    fprintf(fd, "#define FLOAT64_BYTESIZE          %d\n", sizeof(double));
    fprintf(fd, "#define BITS_PER_WORD      %d\n", 8*WORD_BYTESIZE);
    fprintf(fd, "#define LOG2_BITS_PER_WORD  %d\n", log_2(8*WORD_BYTESIZE));
    fprintf(fd, "#define LOG2_BYTES_PER_WORD %d\n", log_2(WORD_BYTESIZE));
    fprintf(fd, "\n");

    U.bytes[0] = 0x01;
    U.bytes[sizeof(unsigned long)-1] = 0x02;



    switch (U.l & 0xFF) {
	//
    case 0x01:
	fprintf(fd, "#define BYTE_ORDER_LITTLE\n");
	break;
	//
    case 0x02:
	fprintf(fd, "#define BYTE_ORDER_BIG\n");
	break;
	//
    default:
	fprintf(stderr, "generate-sizes-of-some-c-types-h.c: Error -- unable to determine endian\n");
	exit(1);
    }

    fprintf (fd, "\n");

    // The C part:
    //
    fprintf (fd, "#ifndef _ASM_\n");

    fprintf(fd, "typedef %s Int16;\n", i16);
    fprintf(fd, "typedef unsigned %s Unt16;\n", i16);
    fprintf(fd, "typedef %s Int1;\n", i32);
    fprintf(fd, "typedef unsigned %s Unt1;\n", i32);

    #if (defined(SIZES_C_64_MYTHRYL_32) || defined(SIZES_C_64_MYTHRYL_64))
	//
	fprintf(fd, "typedef %s Int2;\n", i64);
	fprintf(fd, "typedef unsigned %s Unt2;\n", i64);
    #endif

    fprintf (fd, "\n");
    fprintf (fd, "typedef unsigned char Unt8;\n");

    #if defined(SIZES_C_64_MYTHRYL_32)								// Are we ever going to actually use this?  (No existing file #defines this symbol.)  If not, Punt and Vunt can be combined. XXX BUGGO FIXME.
	//
	fprintf(fd, "typedef Unt1 Vunt;\n");
	fprintf(fd, "typedef Int1      Vint;\n");
	fprintf(fd, "typedef Unt2 Punt;	// \"Punt\" == \"Pointer sized Unt\"\n");
	//
    #elif defined(SIZES_C_64_MYTHRYL_64)
	//
	fprintf(fd, "typedef Unt2 Vunt;\n");
	fprintf(fd, "typedef Int2      Vint;\n");
	fprintf(fd, "typedef Unt2 Punt;	// \"Punt\" == \"Pointer sized Unt\"\n");
	//
    #else	// SIZES_C_32_MYTHRYL_32
	//
	fprintf(fd, "typedef Unt1 Vunt;\n");
	fprintf(fd, "typedef Int1      Vint;\n");
	fprintf(fd, "typedef Unt1 Punt;	// \"Punt\" == \"Pointer sized Unt\"\n");
    #endif

    {   struct stat stat;
	fprintf(fd, "#define SIZEOF_STRUCT_STAT_ST_SIZE %d  // sizeof(struct stat.st_size), for src/c/lib/posix-file-system/stat_64.c\n", sizeof(stat.st_size));	// Added 2010-11-15 CrT
    }

    {   struct flock flock;
	fprintf(fd, "#define SIZEOF_STRUCT_FLOCK_L_START %d  // sizeof(struct flock.l_start), for src/c/lib/posix-io/fcntl_l_64.c\n", sizeof(flock.l_start));	// Added 2010-11-15 CrT
	fprintf(fd, "#define SIZEOF_STRUCT_FLOCK_L_LEN   %d  // sizeof(struct flock.l_len  ), for src/c/lib/posix-io/fcntl_l_64.c\n", sizeof(flock.l_len  ));	// Added 2010-11-15 CrT
    }

    fprintf(fd, "#define SIZEOF_OFF_T %d  // sizeof(off_t), for src/c/lib/posix-io/lseek_64.c\n", sizeof(off_t));	// Added 2010-11-15 CrT

    fprintf(fd, "#endif\n");

    finish_generating_header_file( fd, unique_string );		// finish_generating_header_file	def in    src/c/config/start-and-finish-generating-header-file.c

    exit(0);
}


// COPYRIGHT (c) 1993 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released under Gnu Public Licence version 3.

