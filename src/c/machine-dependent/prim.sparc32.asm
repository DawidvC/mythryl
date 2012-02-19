// prim.sparc32.asm
//
// This file contains asmcoded functions callable directly
// from Mythryl via the runtime::asm API defined in
//
//     src/lib/core/init/runtime.api
//
// These assembly code functions may then request services from
// the C level by passing one of the request codes defined in
//
//     src/c/h/asm-to-c-request-codes.h
//
// to
//
//     src/c/main/run-mythryl-code-and-runtime-eventloop.c
//
// which then dispatches on them to various fns throughout the C runtime.
//
// AUTHOR:  John Reppy
//	    Cornell University
//	    Ithaca, NY 14853
//	    jhr@cs.cornell.edu

#include "asm-base.h"
#include "runtime-base.h"
#include "runtime-values.h"
#include "heap-tags.h"
#include "asm-to-c-request-codes.h"
#include "runtime-configuration.h"
#include "task-and-pthread-struct-field-offsets--autogenerated.h"	// This file is autogenerated.

// SPARC runtime code for Mythryl.
// Registers are used as follows:
//
//	%g0	zero
// 	%g1	standard link
//	%g2-3  	misc regs
//	%g4  	heap limit pointer
// 	%g5  	store pointer
//	%g6  	limit pointer
//   	%g7  	exception handler
//
//	%o0-1	misc regs
//	%o2	asm tmp
//	%o3-5	misc regs
//	%o6  	sp
//   	%o7  	gcLink
//
//	%l0-7   misc regs	
//
//	%i0	standard arg
// 	%i1	standard cont
//	%i2  	standard clos
//	%i3	base ptr
//	%i4  	misc reg
// 	%i5  	var ptr
//	%i6  	fp (don't touch)
//   	%i7  	misc reg 



#define      ZERO			%g0
#define   EXNFATE			%g7		// exception handler        (exception_fate)
#define  HEAP_ALLOCATION_POINTER	%g6		// freespace pointer        (heap_allocation_pointer)
#define  HEAP_CHANGELOG_PTR		%g5		// heap changelog pointer   (heap_changelog)
#define  HEAP_ALLOCATION_LIMIT		%g4		// heap limit pointer       (heap_allocation_limit)
#define    STDARG			%i0		// standard argument        (argument)
#define   STDFATE			%i1		// standard continuation    (fate)
#define   STDCLOS			%i2		// standard closure         (closure)
#define  CURRENT_THREAD_PTR		%i5		// 'current thread' pointer (thread)
#define   STDLINK			%g1		// standard link            (lib7_linkPtr)
#define  MISCREG0			%g2
#define  MISCREG1			%g3
#define  MISCREG2			%o0
#define  PROGRAM_COUNTER		%o7		// program_counter

#define   ASMTMP			%o2		// Assembly temporary used in Mythryl.
#define   TMPREG1			ASMTMP
#define   TMPREG2			%o3   
#define   TMPREG3			%o4
#define   TMPREG4			%o5

// %o2 and %o3 are also used as for multiply and divide.


// %o6 = %sp (not used by Lib7)
// %i6 = %fp (not used by Lib7)
// %i7 = return address to C code (not used by Lib7)
//
// The Mythryl stack frame has the following layout (set up by asm_run_mythryl_task):
//
//	%fp = %sp+4096
//                      +------------------------+
//                      |                        |
//                      .                        .
//			|                        |
//	%sp+116:	|  spill area            |
//			+------------------------+
//	%sp+112:	|     unused	         |
//	%sp+108:	|     unused	         |
//			+------------------------+
//	%sp+104:	|     saved %o7          |
//			+------------------------+
//	%sp+100:	| &call_heapcleaner_asm0 |
//			+------------------------+
//	%sp+96:	        | &Task                  |
//			+------------------------+
//	%sp+92:		|  temp for floor        |
//			+------------------------+
//	%sp+88:		|  temp for cvti2d       |
//			+------------------------+
//      %sp+84:		| &_lib7_udiv            |
//			+------------------------+
//      %sp+80:		| &_lib7_umul            |
//			+------------------------+
//	%sp+76:		| &_lib7_div             |
//			+------------------------+
//	%sp+72:		| &_lib7_mul             |
//			+------------------------+
//	%sp+68:		|     saved %g6          | -- (heap_allocation_pointer)
//			+------------------------+
//	%sp+64:		|     saved %g7          | -- (exception_fate)
//			+------------------------+
//			|   space to save        |
//			|   in and local         |
//	%sp:		|     registers          |
//			+------------------------+
//
// Note that this must be a multiple of 8 bytes.
// The size of the stack frame is:
//
#define LIB7_FRAMESIZE 4096

#define      MUL_OFFSET 72
#define      DIV_OFFSET 76
#define     UMUL_OFFSET 80
#define     UDIV_OFFSET 84
#define    FLOOR_OFFSET 92
#define  TASK_OFFSET 96
#define  RUN_HEAPCLEANER__OFFSET 100			// Offset relative to framepointer of pointer to function which starts a heapcleaning ("garbage collection").
#define      i7_OFFSET 104

#define CONTINUE				\
            jmp     STDFATE;			\
            subcc   HEAP_ALLOCATION_POINTER,HEAP_ALLOCATION_LIMIT,%g0

#define CHECKLIMIT(label)				\
		blu	label;				\
		nop;					\
 		mov	STDLINK,PROGRAM_COUNTER;	\
		ba	CSYM(call_heapcleaner_asm);	\
		nop;					\
	label:


	TEXT

// return_from_signal_handler_asm:
// The return fate for the Mythryl signal handler.
//
LIB7_CODE_HDR(return_from_signal_handler_asm)
	set	HEAP_VOID,STDLINK
	set	HEAP_VOID,STDCLOS
	set	HEAP_VOID,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_RETURN_FROM_SIGNAL_HANDLER,TMPREG3		// (delay slot)

// resume_after_handling_signal:
// Resume execution at the point at which a handler trap occurred.
// This is a standard two-argument function, thus the closure is in
// fate (stdfate).
//
ENTRY(resume_after_handling_signal)
	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_RESUME_SIGNAL_HANDLER,TMPREG3		// (delay slot)

// return_from_software_generated_periodic_event_handler_asm:
// The return fate for the Mythryl software
// generated periodic event handler.
//
LIB7_CODE_HDR( return_from_software_generated_periodic_event_handler_asm )
	set	HEAP_VOID,STDLINK
	set	HEAP_VOID,STDCLOS
	set	HEAP_VOID,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_RETURN_FROM_SOFTWARE_GENERATED_PERIODIC_EVENT_HANDLER,TMPREG3	// (delay slot)

// Here we pick up execution from where we were
// before we went off to handle a software generated
// periodic event:
//
ENTRY(resume_after_handling_software_generated_periodic_event)
	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_RESUME_SOFTWARE_GENERATED_PERIODIC_EVENT_HANDLER,TMPREG3	// (delay slot)

// Exception handler for Mythryl functions called from C.
// We delegate uncaught-exception handling to
//     handle_uncaught_exception  in  src/c/main/runtime-exception-stuff.c
// We get invoked courtesy of being stuffed into
//     task->exception_fate
// in  src/c/main/run-mythryl-code-and-runtime-eventloop.c
// and src/c/heapcleaner/import-heap.c
//
LIB7_CODE_HDR(handle_uncaught_exception_closure_asm)
	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_HANDLE_UNCAUGHT_EXCEPTION,TMPREG3		// (delay slot)



// Here to return to                                     run_mythryl_task_and_runtime_eventloop__may_heapclean	in   src/c/main/run-mythryl-code-and-runtime-eventloop.c
// and thence to whoever called it.  If the caller was   load_and_run_heap_image__may_heapclean			in   src/c/main/load-and-run-heap-image.c
// this will return us to                                main                                   		in   src/c/main/runtime-main.c
// which will print stats
// and exit(), but                   if the caller was   no_args_entry or some_args_entry       		in   src/c/lib/ccalls/ccalls-fns.c
// then we may have some scenario
// where C calls Mythryl which calls C which ...
// and we may just be unwinding on level.
//    The latter can only happen with the
// help of the src/lib/c-glue-old/ stuff,
// which is currently non-operational.
//
// run_mythryl_task_and_runtime_eventloop__may_heapclean is also called by
//     src/c/pthread/pthread-on-posix-threads.c
//     src/c/pthread/pthread-on-sgi.c
//     src/c/pthread/pthread-on-solaris.c
// but that stuff is also non-operational (I think) and
// we're not supposed to return to caller in those cases.
// 
// We get slotted into task->fate by   save_c_state           in   src/c/main/runtime-state.c 
// and by                              run_mythryl_function   in   src/c/main/run-mythryl-code-and-runtime-eventloop.c
//
LIB7_CODE_HDR(return_to_c_level_asm)
	set	HEAP_VOID,STDLINK
	set	HEAP_VOID,STDCLOS
	set	HEAP_VOID,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_RETURN_TO_C_LEVEL,TMPREG3		// (delay slot)

ENTRY(request_fault)
	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_FAULT,TMPREG3		// (delay slot)


// find_cfun : (String, String) -> Cfunction			// (library-name, function-name) -> Cfunction -- see comments in   src/c/heapcleaner/mythryl-callable-cfun-hashtable.c
//
// We get called (only) from:
//
//     src/lib/std/src/unsafe/mythryl-callable-c-library-interface.pkg	
//
LIB7_CODE_HDR(find_cfun_asm)
	CHECKLIMIT(find_cfun_v_limit)
	ba	set_request
	set	REQUEST_FIND_CFUN,TMPREG3		// (delay slot)

LIB7_CODE_HDR(make_package_literals_via_bytecode_interpreter_asm)
	CHECKLIMIT(make_package_literals_via_bytecode_interpreter_a_limit)
	ba	set_request
	set	REQUEST_MAKE_PACKAGE_LITERALS_VIA_BYTECODE_INTERPRETER,TMPREG3	// (delay slot)



// Invoke a C-level function (obtained from find_cfun above) from the Mythryl level.
// We get called (only) from
//
//     src/lib/std/src/unsafe/mythryl-callable-c-library-interface.pkg
//
LIB7_CODE_HDR(call_cfun_asm)
	CHECKLIMIT(call_cfun_a_limit)
	ba	set_request
	set	REQUEST_CALL_CFUN,TMPREG3		// (delay slot)


// This is the entry point called from Mythryl to start a heapcleaning.
// I've added an adjustment to the return address.  The generated Mythryl
// code uses the JMPL instruction, which does not add an offset of 8 to
// the correct return address.
//
//						Allen 6/5/1998
//
ENTRY(call_heapcleaner_asm0)
	add	PROGRAM_COUNTER, 8, PROGRAM_COUNTER
ENTRY(call_heapcleaner_asm)
	set	REQUEST_CLEANING,TMPREG3

	// FALL THROUGH

set_request:
	ld	[%sp+TASK_OFFSET],TMPREG2						// Get Task* from stack.
	ld	[TMPREG2+pthread_byte_offset_in_task_struct],TMPREG1			// TMPREG1 := pthread
	st	%g0,[TMPREG1+executing_mythryl_code_byte_offset_in_pthread_struct]	// Note that we have left Mythryl code.
	st	HEAP_ALLOCATION_POINTER,[TMPREG2+heap_allocation_pointer_byte_offset_in_task_struct]
	st	HEAP_ALLOCATION_LIMIT,[TMPREG2+heap_allocation_limit_byte_offset_in_task_struct]
	st	HEAP_CHANGELOG_PTR,[TMPREG2+heap_changelog_byte_offset_in_task_struct]	// Save heap changelog pointer.
	st	STDLINK,[TMPREG2+link_register_byte_offset_in_task_struct]
	st	PROGRAM_COUNTER,[TMPREG2+program_counter_byte_offset_in_task_struct]	// Program counter of called function.
	st	STDARG,[TMPREG2+argument_byte_offset_in_task_struct]			// Save stdarg.
	st	STDCLOS,[TMPREG2+current_closure_byte_offset_in_task_struct]		// Save current closure.
	st	STDFATE,[TMPREG2+fate_byte_offset_in_task_struct]			// Save stdfate.
	st	CURRENT_THREAD_PTR,[TMPREG2+current_thread_byte_offset_in_task_struct]	// Save 'current thread' pointer.
	st	EXNFATE,[TMPREG2+exception_fate_byte_offset_in_task_struct]		// Save exnfate.
        st      MISCREG0,[TMPREG2+callee_saved_register_0_byte_offset_in_task_struct]
        st      MISCREG1,[TMPREG2+callee_saved_register_1_byte_offset_in_task_struct]
        st      MISCREG2,[TMPREG2+callee_saved_register_2_byte_offset_in_task_struct]

        ldd	[%sp+64],%g6			// Restore C registers %g6 & %g7.
	ld	[%sp+i7_OFFSET],%i7		// Restore C return address.
	mov	TMPREG3,%i0			// Return request code
	ret
	restore					// Delay slot.


#define Task ASMTMP
#define pthreadPtr TMPREG4
ENTRY(asm_run_mythryl_task)
	save	%sp,-SA(LIB7_FRAMESIZE),%sp
	st	%i0,[%sp+TASK_OFFSET]	// Save Task* on stack.
	set	CSYM(call_heapcleaner_asm0),ASMTMP
	st	ASMTMP,[%sp+RUN_HEAPCLEANER__OFFSET]
	mov	%i0,Task			// Transfer Task* tmpreg4.
	std	%g6,[%sp+64]			// Save C registers %g6 & %g7
	st	%i7, [%sp+i7_OFFSET]		// Save C return address.
	set	_lib7_mul,TMPREG4		// Set pointer to ml_mul.
	st	TMPREG4,[%sp+MUL_OFFSET]
	set	_lib7_div,TMPREG4		// Set pointer to ml_div.
	st	TMPREG4,[%sp+DIV_OFFSET]
	set	_lib7_umul,TMPREG4		// Set pointer to ml_umul.
	st	TMPREG4,[%sp+UMUL_OFFSET]
	set	_lib7_udiv,TMPREG4		// Set pointer to ml_udiv.
	st	TMPREG4,[%sp+UDIV_OFFSET]
	ld	[ Task + heap_allocation_pointer_byte_offset_in_task_struct ], HEAP_ALLOCATION_POINTER
	ld	[ Task +   heap_allocation_limit_byte_offset_in_task_struct ], HEAP_ALLOCATION_LIMIT
	ld	[ Task +          heap_changelog_byte_offset_in_task_struct ], HEAP_CHANGELOG_PTR
	ld	[ Task +         program_counter_byte_offset_in_task_struct ], PROGRAM_COUNTER
	ld	[ Task +                argument_byte_offset_in_task_struct ], STDARG  
	ld	[ Task +                    fate_byte_offset_in_task_struct ], STDFATE
	ld	[ Task +         current_closure_byte_offset_in_task_struct ], STDCLOS     
	ld 	[ Task +          current_thread_byte_offset_in_task_struct ], CURRENT_THREAD_PTR
	ld	[ Task +           link_register_byte_offset_in_task_struct ], STDLINK
	ld	[ Task +          exception_fate_byte_offset_in_task_struct ], EXNFATE					// Restore exception_handler_register.
	ld	[ Task + callee_saved_register_0_byte_offset_in_task_struct ], MISCREG0
	ld	[ Task + callee_saved_register_1_byte_offset_in_task_struct ], MISCREG1
	ld	[ Task + callee_saved_register_2_byte_offset_in_task_struct ], MISCREG2
	ld	[ Task +                 pthread_byte_offset_in_task_struct ], pthreadPtr				// TMPREG4 := pthreadPtr
	set	1,TMPREG2												// Note that we have entered Mythryl code.
	st	TMPREG2,[ pthreadPtr +       executing_mythryl_code_byte_offset_in_pthread_struct]
	ld	[         pthreadPtr + all_posix_signals_seen_count_byte_offset_in_pthread_struct],TMPREG2		// Check for pending signals.
	ld	[         pthreadPtr + all_posix_signals_done_count_byte_offset_in_pthread_struct],TMPREG3
	subcc	TMPREG2,TMPREG3,%g0
	bne	pending_sigs
	nop
CSYM(ml_go):					// Invoke the Mythryl code.
	jmp	PROGRAM_COUNTER
	subcc	HEAP_ALLOCATION_POINTER,HEAP_ALLOCATION_LIMIT,%g0		// Heap limit test (delay slot)

pending_sigs:					// There are pending signals.
						// Check if we are currently handling a signal.
	ld	[ pthreadPtr + mythryl_handler_for_posix_signal_is_running_byte_offset_in_pthread_struct ], TMPREG2
	tst	TMPREG2
	bne	ml_go
	set	1,TMPREG2			// (delay slot)
						// Note that a handler trap is pending.
	st	TMPREG2,[ pthreadPtr + posix_signal_pending_byte_offset_in_pthread_struct ]
	ba	ml_go
	mov	HEAP_ALLOCATION_POINTER,HEAP_ALLOCATION_LIMIT		// (delay slot)


#if defined(OPSYS_SUNOS) || defined(OPSYS_NEXTSTEP)
// Zero_Heap_Allocation_Limit:
//
// Zero the heap limit pointer so that a trap will be generated
// on the next limit check and then continue executing Mythryl code.
// NOTE: This code cannot trash any registers (other than heap_allocation_limit)
// or the condition code. To achieve this we work inside a new register window.
// Also note that this code is not needed under SOLARIS 2.x, since we can
// directly change the register from C.

	TEXT
ENTRY(Zero_Heap_Allocation_Limit)
	save	%sp,-SA(WINDOWSIZE),%sp
	sethi	%hi(CSYM(SavedPC)),%l1
	ld	[%l1+%lo(CSYM(SavedPC))],%o0
	set	0,HEAP_ALLOCATION_LIMIT
	jmp	%o0
	restore				// (delay slot)
#endif // OPSYS_SUNOS


// make_typeagnostic_rw_vector:  (Int, X) -> Rw_Vector(X)
// Allocate and initialize a new rw_vector.
// This can trigger cleaning.
//
LIB7_CODE_HDR(make_typeagnostic_rw_vector_asm)
	CHECKLIMIT(make_typeagnostic_rw_vector_a_limit)
	ld	[STDARG],TMPREG1				// tmp1 = length in words
	sra	TMPREG1,1,TMPREG2				// tmp2 = length (untagged)
	cmp	TMPREG2,MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS	// is this a small chunk?
	bgt	3f
	nop
        // Allocate and initialize array data
	ld	[STDARG+4],STDARG				// stdarg = initial value
	sll	TMPREG2,TAGWORD_LENGTH_FIELD_SHIFT,TMPREG3	// build tagword in tmp3
	or	TMPREG3,MAKE_BTAG(RW_VECTOR_DATA_BTAG),TMPREG3
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// store the tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	mov	HEAP_ALLOCATION_POINTER,TMPREG3				// array data ptr in tmp3
1:								// loop
	st	STDARG,[HEAP_ALLOCATION_POINTER]
	deccc	1,TMPREG2					// if (--length > 0)
	bgt	1b						    // then continue 
	inc	4,HEAP_ALLOCATION_POINTER					    // heap_allocation_pointer++ (delay slot)
								// end loop
        // Allocate array header
	set	TYPEAGNOSTIC_RW_VECTOR_TAGWORD,TMPREG2				// tagword in tmp2
	st	TMPREG2,[HEAP_ALLOCATION_POINTER]				// store the tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	mov	HEAP_ALLOCATION_POINTER,STDARG					// result = header addr
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// store pointer to data
	st	TMPREG1,[HEAP_ALLOCATION_POINTER+4]
	inc	8,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer += 2
	CONTINUE

3:	// here we do off-line allocation for big arrays
 	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_MAKE_TYPEAGNOSTIC_RW_VECTOR,TMPREG3	    			// (delayslot)

// make_float64_rw_vector:  Int -> Float64_Rw_Vector
// Create a new Float64_Rw_Vector.
//
LIB7_CODE_HDR(make_float64_rw_vector_asm)
	CHECKLIMIT(make_float64_rw_vector_a_limit)
	sra	STDARG,1,TMPREG2				// tmp2 = length (untagged int)
	sll	TMPREG2,1,TMPREG2				// tmp2 = length in words
	cmp	TMPREG2,MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS	// is this a small chunk?
	bgt	1f
	nop
        // Allocate the data chunk
	sll	TMPREG2,TAGWORD_LENGTH_FIELD_SHIFT,TMPREG1	// build data desc in tmp1
	or	TMPREG1,MAKE_BTAG(EIGHT_BYTE_ALIGNED_NONPOINTER_DATA_BTAG),TMPREG1
#ifdef ALIGN_FLOAT64S
	or	HEAP_ALLOCATION_POINTER,0x4,HEAP_ALLOCATION_POINTER				// desc is unaliged
#endif
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]				// store the data tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	mov	HEAP_ALLOCATION_POINTER,TMPREG3				// tmp3 = data chunk
	sll	TMPREG2,2,TMPREG2				// tmp2 = length in bytes
	add	HEAP_ALLOCATION_POINTER,TMPREG2,HEAP_ALLOCATION_POINTER			// heap_allocation_pointer += length

	        // Allocate the header chunk:
	//
	set	FLOAT64_RW_VECTOR_TAGWORD,TMPREG1
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]				// header tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// header data field
	st	STDARG,[HEAP_ALLOCATION_POINTER+4]				// header length field
	mov	HEAP_ALLOCATION_POINTER,STDARG					// stdarg = header chunk
	inc	8,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer += 2
	CONTINUE

1:	// off-line allocation of big realarrays
 	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_ALLOCATE_VECTOR_OF_EIGHT_BYTE_FLOATS,TMPREG3			// (delayslot)

// make_unt8_rw_vector:  Int -> Unt8_Rw_Vector
// Create a bytearray of the given length.
//
LIB7_CODE_HDR(make_unt8_rw_vector_asm)
	CHECKLIMIT(make_unt8_rw_vector_a_limit)
	sra	STDARG,1,TMPREG2				// tmp2 = length (sparc int)
	add	TMPREG2,3,TMPREG2				// tmp2 = length in words
	sra	TMPREG2,2,TMPREG2
	cmp	TMPREG2,MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS	// Is this a "small chunk" (i.e., one allowed in the arena)?
	bgt	1f
	nop
        // Allocate the data chunk:
		sll	TMPREG2,TAGWORD_LENGTH_FIELD_SHIFT,TMPREG1	// build data desc in tmp1
	or	TMPREG1,MAKE_BTAG(FOUR_BYTE_ALIGNED_NONPOINTER_DATA_BTAG),TMPREG1
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]				// store the data tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	mov	HEAP_ALLOCATION_POINTER,TMPREG3				// tmp3 = data chunk
	sll	TMPREG2,2,TMPREG2				// tmp2 = length in bytes
	add	HEAP_ALLOCATION_POINTER,TMPREG2,HEAP_ALLOCATION_POINTER			// heap_allocation_pointer += length

	// Allocate the header chunk:
	//
	set	UNT8_RW_VECTOR_TAGWORD,TMPREG1				// header tagword
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// header data field
	st	STDARG,[HEAP_ALLOCATION_POINTER+4]				// header length field
	mov	HEAP_ALLOCATION_POINTER,STDARG					// stdarg = header chunk
	inc	8,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer += 2
	CONTINUE

1:	// Here we do off-line allocation for big bytearrays
 	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_ALLOCATE_BYTE_VECTOR,TMPREG3			// (delayslot)

// make_string:  Int -> String
// Create a string of the given length (> 0).
//
LIB7_CODE_HDR(make_string_asm)
	CHECKLIMIT(make_string_a_limit)
	sra	STDARG,1,TMPREG2				// tmp2 = length (sparc int)
	add	TMPREG2,4,TMPREG2				// tmp2 = length in words
								//  (including zero at end).
	sra	TMPREG2,2,TMPREG2
	cmp	TMPREG2,MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS	// Is this a small chunk?
	bgt	1f
	nop

	// Allocate the data chunk:
	//	
	sll	TMPREG2,TAGWORD_LENGTH_FIELD_SHIFT,TMPREG1	// Build data desc in tmp1
	or	TMPREG1,MAKE_BTAG(FOUR_BYTE_ALIGNED_NONPOINTER_DATA_BTAG),TMPREG1
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]				// store the data tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	mov	HEAP_ALLOCATION_POINTER,TMPREG3				// tmp3 = data chunk
	sll	TMPREG2,2,TMPREG2				// tmp2 = length in bytes
	add	HEAP_ALLOCATION_POINTER,TMPREG2,HEAP_ALLOCATION_POINTER			// heap_allocation_pointer += length
	st	%g0,[HEAP_ALLOCATION_POINTER-4]				// store 0 in last word of data

		// Allocate the header chunk:
	//	
	set	STRING_TAGWORD,TMPREG1				// header tagword
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// header data field
	st	STDARG,[HEAP_ALLOCATION_POINTER+4]				// header length field
	mov	HEAP_ALLOCATION_POINTER,STDARG					// stdarg = header chunk
	inc	8,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer += 2
	CONTINUE

1:	// Here we do off-line allocation for big strings.
 	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_ALLOCATE_STRING,TMPREG3			// (delayslot)


// make_vector_asm:  (Int, List(X)) -> Vector(X)			// (length_in_slots, initializer_list) -> result_vector
//
//	Create a vector and initialize from given list.
//
//	Caller guarantees that length_in_slots is
//      positive and also the length of the list.
//	For a sample client call see
//          fun vector
//	in
//	    src/lib/core/init/pervasive.pkg
//
LIB7_CODE_HDR(make_vector_asm)
	CHECKLIMIT(make_vector_a_limit)
	ld	[STDARG],TMPREG1				// tmp1 = length (tagged int)
	sra	TMPREG1,1,TMPREG2				// tmp2 = length (untagged int)
	cmp	TMPREG2,MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS	// Is this a "small chunk" (i.e., one allowed in the arena)?
	bgt	1f
	nop
        // Allocate and initialize data chunk:
	// 
	sll	TMPREG2,TAGWORD_LENGTH_FIELD_SHIFT,TMPREG2	// Build tagword in TMPREG2.
	or	TMPREG2,MAKE_BTAG(RO_VECTOR_DATA_BTAG),TMPREG2
	st	TMPREG2,[HEAP_ALLOCATION_POINTER]				// Store the tagword.
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	ld	[STDARG+4],TMPREG2				// tmp2 = list
	mov	HEAP_ALLOCATION_POINTER,STDARG					// stdarg = data chunk
2:								// loop
	ld	[TMPREG2],TMPREG3				// tmp3 = hd(tmp2)
	ld	[TMPREG2+4],TMPREG2				// tmp2 = tl(tmp2)
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// Store element.
	cmp	TMPREG2,HEAP_NIL				// if (tmp2 <> NIL) goto loop.
	bne	2b
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++ (delay slot)
								// end loop.
        // Allocate header chunk:
	//
	set	TYPEAGNOSTIC_RO_VECTOR_TAGWORD,TMPREG3				// Tagword in TMPREG3
	st	TMPREG3,[HEAP_ALLOCATION_POINTER]				// Header tagword
	inc	4,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer++
	st	STDARG,[HEAP_ALLOCATION_POINTER]				// header data field
	st	TMPREG1,[HEAP_ALLOCATION_POINTER+4]				// header length field
	mov	HEAP_ALLOCATION_POINTER,STDARG					// result = header chunk
	inc	8,HEAP_ALLOCATION_POINTER					// heap_allocation_pointer += 2
	CONTINUE

1:	// Off-line allocation of big vectors:	
 	mov	STDLINK,PROGRAM_COUNTER
	ba	set_request
	set	REQUEST_MAKE_TYPEAGNOSTIC_RO_VECTOR,TMPREG3			// (delayslot)


// floor : Float -> Int
// Return the floor of the argument.
// Do not check for out-of-range -- it is the Mythryl
// code's responsibility to check before calling.
//
LIB7_CODE_HDR(floor_asm)
	ld	[STDARG],%f0					// Fetch arg into %f0, %f1.
	ld	[STDARG+4],%f1
	ld	[STDARG],TMPREG2				// tmpreg2 gets high word.
	tst	TMPREG2						// Negative ?
	blt	1f
	nop
								// Handle positive case.
	fdtoi	%f0,%f2						// Convert to int (round towards 0).
	st	%f2,[%sp+FLOOR_OFFSET]
	ld	[%sp+FLOOR_OFFSET],TMPREG2			// tmpreg2 gets int result (via stack temp).
	add	TMPREG2,TMPREG2,TMPREG2
	add	TMPREG2,1,STDARG
	CONTINUE
	
1:								// Handle negative case.
	fdtoi	%f0,%f2						// Convert to int (round towards 0).
	st	%f2,[%sp+FLOOR_OFFSET]
	fitod	%f2,%f4						// Convert back to real to check for fraction.
	fcmpd	%f0,%f4						// Same value?
	ld	[%sp+FLOOR_OFFSET],TMPREG2			// tmpreg2 gets int result (via stack temp).
	fbe	2f						// Check result of fcmpd.
	nop
	dec	TMPREG2						// Push one lower.
2:								// Convert result to Mythryl int and continue.
	add	TMPREG2,TMPREG2,TMPREG2
	add	TMPREG2,1,STDARG
	CONTINUE

// logb : Float -> Int
// Extract and unbias the exponent.
// The IEEE bias is 1023.
//
LIB7_CODE_HDR(logb_asm)
	ld	[STDARG],TMPREG2				// Extract exponent.
	srl	TMPREG2,19,TMPREG2
	and	TMPREG2,2047*2,TMPREG2				// Unbias and convert to Mythryl int.
	sub	TMPREG2,2045,STDARG			  	// 2(n-1023)+1 == 2n-2045.
	CONTINUE


// scalb : (real * int) -> real
// Scale the first argument by 2 raised to the second argument.
// Raise Float("underflow") or Float("overflow") as appropriate.
//
LIB7_CODE_HDR(scalb_asm)
	CHECKLIMIT(scalb_a_limit)
	ld	[STDARG+4],TMPREG1					// tmpreg1 gets scale (second arg)
	sra	TMPREG1,1,TMPREG1					// Convert scale to sparc int. 
	ld	[STDARG],STDARG						// stdarg gets float (first arg).
	ld	[STDARG],TMPREG4					// tmpreg4 gets high word of float value.
	set	0x7ff00000,TMPREG2					// tmpreg2 gets exponent mask.
	andcc	TMPREG4,TMPREG2,TMPREG3					// Extract exponent into tmpreg3.
	be	1f		    					// If 0 then return same.
	nop
	srl	TMPREG3,20,TMPREG3					// Convert exp to int (delay slot).
	addcc	TMPREG3,TMPREG1,TMPREG1					// tmpreg1 = exp + scale
	ble	under							// If new exp <= 0 then underflow.
	nop
	cmp	TMPREG1,2047						// If new exp >= 2047 then overflow.
	bge	over
	nop
	andn	TMPREG4,TMPREG2,TMPREG4					// Mask out old exponent.
	sll	TMPREG1,20,TMPREG1					// Shift new exp to exponent position.
	or	TMPREG4,TMPREG1,TMPREG4					// Set new exponent.
	ld	[STDARG+4],TMPREG1					// tmpreg1 gets low word of float value.
7:
#ifdef ALIGN_FLOAT64S
	or	HEAP_ALLOCATION_POINTER,0x4,HEAP_ALLOCATION_POINTER	// Tagword is unaligned.
#endif
	st	TMPREG4,[HEAP_ALLOCATION_POINTER+4]			// Allocate the new float value.
	st	TMPREG1,[HEAP_ALLOCATION_POINTER+8]
	set	FLOAT64_TAGWORD,TMPREG1
	st	TMPREG1,[HEAP_ALLOCATION_POINTER]
	add	HEAP_ALLOCATION_POINTER,4,STDARG			// Set result.
	inc	12,HEAP_ALLOCATION_POINTER				// heap_allocation_pointer += 3
1:	CONTINUE

over:									// Handle overflow.
	t	ST_INT_OVERFLOW						// Generate an OVERFLOW exception.  We do this
	// Never get here.						// via a trap to produce a SIGOVFL.

under:									// Handle underflow.
	set	0,TMPREG4
	set	0,TMPREG1
	ba	7b
	nop

//////////////////////////////////////////////////////////////
// Integer multiplication and division routines
	.global .mul, .div, .umul, .udiv

// ml_mul:
// multiply %o2 by %o3, returning the result in %o2
// Note: this code assumes that .mul doesn't trash any global or input
// registers.
//
_lib7_mul:
	save	%sp,-SA(WINDOWSIZE),%sp
// NOTE: This can be avoided if %g1, %g2, %g3 are not callee save.
// NOTE: .mul doesn't use %g2, %g3, but the dynamic linking initialization does.
//
	mov	%g1,%l1			// Save %g1 which may get trashed.
	mov	%g2,%l2
	mov	%g3,%l3
	mov	%i2,%o0
	call	.mul
	mov	%i3,%o1			// (delay slot)
	mov	%l1,%g1			// Restore %g1.
	mov	%l2,%g2
	mov	%l3,%g3
	bnz	1f			// If z is clear, then overflow.
	restore %o0,0,%o2		// Result in %o2 (delay slot).
	retl
	nop
1:					// Handle overflow.
	t	ST_INT_OVERFLOW		// Generate an OVERFLOW exceptionn.
					// We do this via a trap to produce a SIGOVFL.

// ml_div:
// divide %o2 by %o3, returning the result in %o2.
// Note: .div uses %g1, %g2 and %g3, so we must save them.  We do this using the
// locals of the new window, since .div is a leaf routine.
//
_lib7_div:
	save	%sp,-SA(WINDOWSIZE),%sp
	addcc	%i3,%g0,%o1		// %o1 is divisor (and check for zero)
	bz	1f
					// Save %g1, %g2 and %g3 (using new window).
// NOTE:  This can be avoided if %g1, %g2, %g3 are not callee save.
	mov	%g1,%l1			// (delay slot)
	mov	%g2,%l2
	mov	%g3,%l3
	call	.div
	mov	%i2,%o0			// (delay slot)
					// Restore %g1, %g2 and %g3.
	mov	%l3,%g3
	mov	%l2,%g2
	mov	%l1,%g1
	ret
	restore %o0,0,%o2		// Result in %o2 (delay slot).
1:					// Handle zero divide.
	restore				// Restore Mythryl window.
	t	ST_DIV0			// Generate a DIVIDE_BY_ZERO exception.
					// We do this via a trap to produce a SIGDIV.

// ml_umul:
// multiply %o2 by %o3 (unsigned), returning the result in %o2.  This does
// raise OVERFLOW.
// Note: this code assumes that .mul doesn't trash any global or input
// registers.
//
_lib7_umul:
	save	%sp,-SA(WINDOWSIZE),%sp
// NOTE:  This can be avoided if %g1, %g2, %g3 are not callee save.
// NOTE: .mul doesn't use %g2, %g3, but the dynamic linking initialization
// does.
//
	mov	%g1,%l1			  // Save %g1 which may get trashed.
	mov	%g2,%l2
	mov	%g3,%l3
	mov	%i2,%o0
	call	.umul
	mov	%i3,%o1			  // (delay slot)
	mov	%l1,%g1			  // Restore %g1.
	mov	%l2,%g2
	mov	%l3,%g3
	ret
	restore %o0,0,%o2		  // Result in %o2 (delay slot).


// ml_udiv:
// Divide %o2 by %o3 (unsigned), returning the result in %o2.
// Note: .udiv uses %g1, %g2 and %g3, so we must save them.
// We do this using the locals of the new window, since .div is a leaf routine.
//
_lib7_udiv:
	save	%sp,-SA(WINDOWSIZE),%sp
	addcc	%i3,%g0,%o1		// %o1 is divisor (and check for zero).
	bz	1f
					// Save %g1, %g2 and %g3 (using new window).
/** NOTE: This can be avoided if %g1, %g2, %g3 are not callee save.
	mov	%g1,%l1			// (delay slot)
	mov	%g2,%l2
	mov	%g3,%l3
	call	.udiv
	mov	%i2,%o0			// (delay slot)
					// Restore %g1, %g2 and %g3.
	mov	%l3,%g3
	mov	%l2,%g2
	mov	%l1,%g1
	ret
	restore %o0,0,%o2		// Result in %o2 (delay slot).
1:					// Handle zero divide.
	restore				// Restore Mythryl window.
	t	ST_DIV0			// Generate a DIVIDE_BY_ZERO exception.
					// We do this via a trap to produce a SIGDIV.


// try_lock : Spin_Lock -> Bool
// low-level test-and-set style primitive for mutual-exclusion among 
// processors.
//
LIB7_CODE_HDR(try_lock_asm)
#if (MAX_PROCS > 1)
	???
#else (MAX_PROCS == 1)
	ld	[STDARG],TMPREG1	// Load previous value into tmpreg1.
	set	HEAP_FALSE,TMPREG4	// HEAP_FALSE
	st	TMPREG4,[STDARG]	// Store HEAP_FALSE into the lock.
	mov	TMPREG1,STDARG		// Return previous value of lock.
	CONTINUE
#endif

// unlock : releases a spin lock 
//
LIB7_CODE_HDR(unlock_asm)
#if (MAX_PROCS > 1)
	???
#else (MAX_PROCS == 1)
	set	HEAP_TRUE,TMPREG1	// Store HEAP_TRUE ...
	st	TMPREG1,[STDARG]	// ... into the lock.
	set	HEAP_VOID,STDARG	// return Void.
	CONTINUE
#endif


// SetFSR:
// Load the floating-point status register with the given word.
//
ENTRY(SetFSR)
	set	fsrtmp,%o1
	st	%o0,[%o1]
	retl
	ld	[%o1],%fsr		// (delay slot)
	DATA
fsrtmp:	.word	0
	TEXT


// void FlushICache (char *addr, int nbytes)
//
ENTRY(FlushICache)
	and	%o1,0x1F,%o2		// m <- (nbytes % (32-1)) >> 2 (use %o2 for m)
	srl	%o2,2,%o2
	srl	%o1,5,%o1		// i <- (nbytes >> 5)
// FLUSH4 implements: if (m > 0) { FLUSH addr; addr += 4; m--;} else goto L_test
#define FLUSH4					\
		tst	%o2;			\
		ble	L_test;			\
		nop;				\
		iflush	%o0;			\
		inc	4,%o0;			\
		dec	1,%o2
	FLUSH4
	FLUSH4
	FLUSH4
	FLUSH4
	FLUSH4
	FLUSH4
	FLUSH4
					// addr is 32-byte aligned here.
L_test:
	tst	%o1
	be	L_exit
	nop
L_loop:					// Flush 32 bytes per iteration.
	iflush	%o0
	iflush	%o0+8
	iflush	%o0+16
	iflush	%o0+24
	deccc	1,%o1			// if (--i > 0) goto L_loop
	bg	L_loop
	inc	32,%o0			// addr += 32 (delay slot)
L_exit:
	retl
	nop


// COPYRIGHT (c) 1992 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2011,
// released under Gnu Public Licence version 3.

