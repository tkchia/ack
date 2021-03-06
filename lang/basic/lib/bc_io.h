#include <stdio.h>

/* BASIC file io definitions */

extern FILE *_chanrd;
extern FILE *_chanwr;
extern int   _chann;
/* BASIC file descriptor table */
/* Channel assignment:
   -1		terminal IO
    0		data file
    1-15	user files
*/

/* FILE MODES:*/
#define 	IMODE	1
#define		OMODE	2
#define		RMODE	3

typedef struct {
	char	*fname;
	FILE	*fd;
	int	pos;
	int	mode;	
	int	reclength;
	}Filedesc;
extern Filedesc	 _fdtable[16];
