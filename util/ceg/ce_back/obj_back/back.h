/* This file must be included in all the files which use the backlibrary.
 */

extern char *extnd_name(), *extnd_dnam(), *extnd_dlb(), *extnd_ilb(),
	    *extnd_hol(), *extnd_ext(), *extnd_pro(), *extnd_start();
extern holno, procno;

#include "data.h"

/* These routines are called very often, thus we turned them into macros. */

#define text1(b) {if (text-text_area>=size_text)  mem_text() ; *text++=b;}
#define con1(b) {if (data-data_area>=size_data) mem_data(); *data++ = b;}
#define rom1(b) {if (data-data_area>=size_data) mem_data(); *data++=b;}
#define bss( n)		( nbss += n)


/* Numbering of the segments and some global constants */

#define 	SEGTXT		0
#define 	SEGROM		1
#define 	SEGCON		2
#define 	SEGBSS		3

#define swtxt()		switchseg( SEGTXT)

#define 	PC_REL  	1
#define 	ABSOLUTE 	!PC_REL


/* Initialize values. */

#define MAXTEXT		20
#define MAXDATA		20
#define	MAXRELO		3
#define	MAXNAME		5
#define	MAXSTRING	20
#define MAXHASH		256

