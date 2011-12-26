/* hexdump-if.h
 *
 */

extern void   hexdump(  void (*writefn)(void*, char*), void* writefn_arg,	// Continuation receiving our output. writefn is often dump_buf_to_fd() (below), in which case writefn_arg is the fd. 
			char* message,						// Explanatory title string for human consumption.
			unsigned char* data,					// Data to be hexdumped.
			int data_len						// Length of preceding.
		     );

extern void   hexdump_if   (char* message, unsigned char* data, int data_len);
    //
    // Version of above specialized to write to log_if_fd (if nonzero).

