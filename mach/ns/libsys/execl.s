.define _execl
.sect .text
.sect .rom
.sect .data
.sect .bss
.sect .text
.extern _execl
.sect .text
_execl:
enter[], 0
movd @__penvp,tos
addr 12(fp),tos
movd 8(fp),tos
movd 59,tos
jsr @.mon
movd tos,r7
movd r7,@_errno
movd -1,r4
exit []
ret 0