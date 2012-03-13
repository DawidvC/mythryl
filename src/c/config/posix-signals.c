// posix-signals.c
//
// Compute the signal table information for UNIX systems.  This is used to
// generate the posix-signal-table--autogenerated.c file and the system-signals.h file.  We
// assume that the  signals SIGHUP, SIGINT, SIGQUIT, SIGALRM, and SIGTERM
// are (at least) provided.

#include "../mythryl-config.h"

#include "system-dependent-unix-stuff.h"
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include "header-file-autogeneration-stuff.h"
#include "generate-system-signals.h-for-posix-systems.h"


////////////////////////////////////
// The POSIX signals:
//
Signal_Descriptor	SigTable[] = {
	{ SIGHUP,	"SIGHUP",	"HUP"},		// POSIX
	{ SIGINT,	"SIGINT",	"INTERRUPT"},	// POSIX
	{ SIGQUIT,	"SIGQUIT",	"QUIT"},	// POSIX
	{ SIGALRM,	"SIGALRM",	"ALARM"},	// POSIX
	{ SIGTERM,	"SIGTERM",	"TERMINAL"},	// POSIX
#ifdef SIGPIPE
	{ SIGPIPE,	"SIGPIPE",	"PIPE"},	// POSIX
#endif
#ifdef SIGUSR1
	{ SIGUSR1,	"SIGUSR1",	"USR1"},	// POSIX
#endif
#ifdef SIGUSR2
	{ SIGUSR2,	"SIGUSR2",	"USR2"},	// POSIX
#endif
#if defined(SIGCHLD)
	{ SIGCHLD,	"SIGCHLD",	"CHLD"},	// POSIX
#elif defined(SIGCLD)
	{ SIGCLD,	"SIGCLD",	"CHLD"},
#endif
#if defined(SIGWINCH)
	{ SIGWINCH,	"SIGWINCH",	"WINCH"},
#elif defined(SIGWINDOW)
	{ SIGWINDOW,	"SIGWINDOW",	"WINCH"},
#endif
#ifdef SIGURG
	{ SIGURG,	"SIGURG",	"URG"},
#endif
#ifdef SIGIO
	{ SIGIO,	"SIGIO",	"IO"},
#endif
#ifdef SIGPOLL
	{ SIGPOLL,	"SIGPOLL",	"POLL"},
#endif
#ifdef SIGTSTP
	{ SIGTSTP,	"SIGTSTP",	"TSTP"},	// POSIX
#endif
#ifdef SIGCONT
	{ SIGCONT,	"SIGCONT",	"CONT"},	// POSIX
#endif
#ifdef SIGTTIN
	{ SIGTTIN,	"SIGTTIN",	"TTIN"},	// POSIX
#endif
#ifdef SIGTTOU
	{ SIGTTOU,	"SIGTTOU",	"TTOU"},	// POSIX
#endif
#ifdef SIGVTALRM
	{ SIGVTALRM,	"SIGVTALRM",	"VTALRM"},
#endif
};
#define TABLE_SIZE	(sizeof(SigTable)/sizeof(Signal_Descriptor))

// Run-time system generated signals:
//
Signal_Descriptor    RunTSignals[] = {
	{ -1,           "RUNSIG_GC",    "CLEANING" },
};
#define RUNTIME_GENERATED_SIGNAL_COUNT  (sizeof(RunTSignals)/sizeof(Signal_Descriptor))

Runtime_System_Signal_Table*   sort_runtime_system_signal_table   () {
    //
    Signal_Descriptor**  signals =   MALLOC_VEC( Signal_Descriptor*, TABLE_SIZE + RUNTIME_GENERATED_SIGNAL_COUNT);

    // Sort the signal table by increasing signal number.
    // The sort removes duplicates by mapping to the first name.
    // We need this because some systems alias signals.
    //
    int n = 0;
    for (int i = 0;  i < TABLE_SIZE;  i++) {

        // Invariant: signals[0..n-1] is sorted
        //
	Signal_Descriptor*	p = &(SigTable[i]);

	int  j;
	for (j = 0;  j < n;  j++) {
	    //
	    if (signals[j]->sig == p->sig)		break;	      // A duplicate.

	    if (signals[j]->sig > p->sig) {
	        //
                // Insert the signal at position j:
                //
		for (int k = n;  k >= j;  k--)   signals[k] = signals[k-1];
		//
		signals[j] = p;
		n++;
		break;
	    }
	}
	if (j == n) {
	    signals[n++] = p;
	}
    }

    // Here, n is the number of system signals and
    // signals[n-1]->sig is the largest system signal code.
    //

    // Add the run-time system signals to the table:
    //
    for (int i = 0, j = n;  i < RUNTIME_GENERATED_SIGNAL_COUNT;  i++, j++) {
	//
	signals[j] =  &RunTSignals[i];
	//
	signals[j]->sig =  signals[n-1]->sig + i+1;
    }

    Runtime_System_Signal_Table*  signal_db
	=
	MALLOC_CHUNK( Runtime_System_Signal_Table );

    signal_db->sigs	= signals;
    signal_db->posix_signal_kinds	= n;
    signal_db->runtime_generated_signal_kinds	= RUNTIME_GENERATED_SIGNAL_COUNT;
    signal_db->lowest_valid_posix_signal_number	= signals[0]->sig;
    signal_db->highest_valid_posix_signal_number	= signals[n-1]->sig;

    return signal_db;

}


// COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released under Gnu Public Licence version 3.


