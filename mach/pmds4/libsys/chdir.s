.define _chdir
.sect .text
.sect .rom
.sect .data
.sect .bss
.sect .text
.extern _chdir
_chdir:			trap #0
.data2	0xC
			bcc	1f
			jmp	cerror
1:
			clr.l	d0
			rts
