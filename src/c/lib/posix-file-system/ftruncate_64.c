// ftruncate_64.c
//
//   Version of ftruncate with 64-positions passed as pair of 32-bit values.


#include "../../mythryl-config.h"

#include <stdio.h>
#include <errno.h>

#include "system-dependent-unix-stuff.h"
#include "make-strings-and-vectors-etc.h"
#include "lib7-c.h"
#include "cfun-proto-list.h"

#if HAVE_SYS_TYPES_H
    #include <sys/types.h>
#endif

#if HAVE_SYS_STAT_H
    #include <sys/stat.h>
#endif



// One of the library bindings exported via
//     src/c/lib/posix-file-system/cfun-list.h
// and thence
//     src/c/lib/posix-file-system/libmythryl-posix-file-system.c



Val   _lib7_P_FileSys_ftruncate_64   (Task* task,  Val arg)   {
    //============================
    //
    // Mythryl type: (Int, Unt1,    Unt1) -> Void
    //                fd   lengthhi  lengthlo
    //
    // Make a directory.
    //
    // This fn gets bound as   ftruncate'   in:
    //
    //     src/lib/std/src/posix-1003.1b/posix-file-system-64.pkg

    int		    fd = GET_TUPLE_SLOT_AS_INT(arg, 0);
    //
    off_t	    len =
      (sizeof(off_t) > 4)
      ? (((off_t)WORD_LIB7toC(GET_TUPLE_SLOT_AS_VAL(arg, 1))) << 32) |
        ((off_t)(WORD_LIB7toC(GET_TUPLE_SLOT_AS_VAL(arg, 2))))
      : ((off_t)(WORD_LIB7toC(GET_TUPLE_SLOT_AS_VAL(arg, 2))));

    int		    status;

/*  do { */										// Backed out 2010-02-26 CrT: See discussion at bottom of src/c/lib/socket/connect.c

    CEASE_USING_MYTHRYL_HEAP( task->pthread, "_lib7_Date_ascii_time", arg );
	    //
	    status = ftruncate (fd, len);						// Since this call can return EINTR, it is slow and deserves the CEASE/BEGIN guards.
	    //
	BEGIN_USING_MYTHRYL_HEAP( task->pthread, "_lib7_Date_ascii_time" );

/*  } while (status < 0 && errno == EINTR);	*/					// Restart if interrupted by a SIGALRM or SIGCHLD or whatever.

    CHECK_RETURN_UNIT(task, status)
}


// Copyright (c) 2004 by The Fellowship of SML/NJ
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2011,
// released under Gnu Public Licence version 3.

