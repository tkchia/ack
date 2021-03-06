#
! $Source$
! $State$
! $Revision$

! Declare segments (the order is important).

.sect .text
.sect .rom
.sect .data
.sect .bss

MAX_ARGV = 10

.sect .bss
STACKSIZE = 512
.comm stack, STACKSIZE

.sect .text
begtext:
	! Check if bss would overlap BDOS.  We must not overwrite
	! BDOS and crash CP/M.  We cheat by comparing only high bytes
	! of each address.

	lda 0x0007
	mov c, a        ! c = high byte of BDOS address
	lda _cpm_ram+1  ! a = high byte of top of BSS, a.k.a. _end
	cmp c
	lxi d, noroom
	mvi c, 9
	jnc 0x0005      ! print error and exit if a >= c

	! We have to clear the bss. (argify requires it.)
	
	lxi h, begbss
	lxi b, endbss
	mvi e, 0
1:
	mov m, e
	inx h
	mov a, b
	cmp h
	jnz 1b
	mov a, c
	cmp l
	jnz 1b

	! Set up the stack (now it's been cleared, since it's in the BSS).

	lxi h, 0
	dad sp
	shld saved_sp			! save old stack pointer
	lxi sp, stack + STACKSIZE

	! Initialise the rsts (if desired).

	#ifdef USE_I80_RSTS
		call .rst_init
	#endif

    ! Now the 'heap'.

	lhld 0x0006              ! BDOS entry point
	lxi d, -0x806            ! offset to start of CCP
	dad d                    
	shld _cpm_ramtop

	! C-ify the command line at 0x0080.

	lxi h, 0x0080
	mov a, m                 ! a = length of command line
	cpi 0x7F                 ! 127-byte command lines...
	jnz 1f
	dcr a                    ! ...lose the last character 
1:
	adi 0x81                 ! write a 0 at 0x0081+length
	mov l, a
	mov m, h
	
	! Now argify it.
	
	lxi b, 0x0081            ! bc = command line pointer
	lxi h, argv              ! hl = argv pointer

loop_of_argify:
	ldax b			! a = next character
	ora a			! check for end of string
	jz end_of_argify
	cpi ' '			! scan for non-space
	jz 2f

	mov m, c		! put next argument in argv
	inx h
	mov m, b
	inx h

	lda argc		! increment argc
	inr a
	sta argc
	cpi MAX_ARGV		! exit loop if argv is full
	jz end_of_argify

1:	inx b			! scan for space
	ldax b
	ora a
	jz end_of_argify
	cpi ' '
	jnz 1b

	xra a			! replace the space with a '\0'
	stax b

2:	inx b
	jmp loop_of_argify
end_of_argify:

	! Add the fake parameter for the program name.
	
	lxi h, progname
	shld argv0
	lxi h, argc
	inr m
	
	! Push the main() arguments and go.
	
	lxi h, envp
	push h
	lxi h, argv0
	push h
	lhld argc                ! slightly evil
	mvi h, 0
	push h
	call __m_a_i_n
.define _cpm_exit, EXIT, __exit
_cpm_exit:
EXIT:
__exit:
	stc                      ! set carry bit
	jnc _cpm_warmboot        ! warm boot if not set
saved_sp = . + 1
	lxi sp, 0                ! patched on startup
	ret
	.align 2

! Emergency exit routine.

.define _cpm_warmboot
_cpm_warmboot = 0
	
! Special CP/M stuff.

.define _cpm_fcb, _cpm_fcb2
_cpm_fcb = 0x005c
_cpm_fcb2 = 0x006c

.define _cpm_ramtop
.comm _cpm_ramtop, 2

.define _cpm_default_dma
_cpm_default_dma = 0x0080

.define _cpm_iobyte
_cpm_iobyte = 3

.define _cpm_cmdlinelen, _cpm_cmdline
_cpm_cmdlinelen = 0x0080
_cpm_cmdline = 0x0081

! Define symbols at the beginning of our various segments, so that we can find
! them. (Except .text, which has already been done.)

.define begtext, begdata, begbss
.sect .data;       begdata:
.sect .rom;        begrom:
.sect .bss;        begbss:

! Some magic data. All EM systems need these.

.define .ignmask, _errno
.comm .ignmask, 2
.comm _errno, 2

! Used to store the argv array.

.sect .bss
argc: .space 2          ! number of args
argv0: .space 2         ! always points at progname
argv: .space 2*MAX_ARGV ! argv array (must be after argv0)
envp: .space 2          ! envp array (always empty, must be after argv)

! These are used specifically by the i80 code generator.

.define .retadr, .retadr1
.define .bcreg, .areg
.define .tmp1, .fra, block1, block2, block3

.comm .retadr, 2        ! used to save return address
.comm .retadr1, 2       ! reserve
.comm .bcreg, 2
.comm .areg, 2
.comm .tmp1, 2
.comm .fra, 8           ! 8 bytes function return area
block1: .space 4        ! used by 32 bits divide and
block2: .space 4        ! multiply routines
block3: .space 4        ! must be contiguous (.comm doesn't guarantee this)

.sect .data
.define _cpm_ram
_cpm_ram: .data2 __end

.sect .rom
progname: .asciz 'ACKCPM'
noroom: .ascii 'No room$'
