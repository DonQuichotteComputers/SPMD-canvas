// DonQuichotte 2017/05/29

// .S extension, contrary to .s, allows C preprocessing (#define, macros...)

.file   "e_main.S"
.section .text    

// .global will make the symbols visible from other C linked subprograms
.globl inc64asm
.globl inc64asm2

#define arg1   r0


.balign 8
test:
  eor arg1, arg1, arg1
  rts

#undef arg1

.balign 8
inc64asm_bad:

  ldrd.l r2,[r0]
  isub ip, r63, r63
  sub  r2, r2,  r63
  moveq.l ip, r63
  nop
  sub.l  r3, r3, ip // do NOT use isub: it would stall E1
  nop
  nop
  nop
  nop
  strd.l r2, [r0]
  rts


.balign 8
inc64asm_bad2:

  ldr r1,[r0]
  isub r2,r63,r63
  ldr r3,[r0,0x1]
  sub r1,r1,r63
  movgteu r2,r63
  sub r2,r3,r2
  str r1,[r0]
  str r2,[r0,0x1]
  rts

.balign 8
inc64asm:

// My suggestion for inc64asm(var):
// -Ofast -mfp-mode=int -m1reg-r63
// IN: r0 = offset(var)
// OUT: updated var
// TMP: ip, r2, r3
/* 32 au lieu de 21 IC
  ldr r1,[r0]
  isub r2,r63,r63
  ldr r3,[r0,0x1]
  sub r1,r1,-1
  movgteu r2,r63
  sub r2,r3,r2
  str r1,[r0]
  str r2,[r0,0x1]
  rts
*/  

  ldr r1,[r0]
  isub r2,r63,r63
  ldr r3,[r0,0x1]
  sub r1,r1,-1
  mov ip,0x1
  movgteu r2,ip
  add r2,r2,r3
  str r1,[r0]
  str r2,[r0,0x1]
  rts

/* from gcc 5.4:

  ldr r1,[r0]
  ldr r3,[r0,0x1]
  sub r1,r1,-1
  mov r2,0x0
  mov ip,0x1
  movgteu r2,ip
  add r2,r2,r3
  str r1,[r0]
  str r2,[r0,0x1]
  rts
*/

/* e-objdump -s bin/e_main.elf:

00000af0 <inc64>:
 af0:	2044      	ldr r1,[r0]
 af2:	60c4      	ldr r3,[r0,0x1]
 af4:	27b3      	sub r1,r1,-1
 af6:	4003      	mov r2,0x0
 af8:	802b 2002 	mov ip,0x1
 afc:	503f 0402 	movgteu r2,ip
 b00:	499a      	add r2,r2,r3
 b02:	2054      	str r1,[r0]
 b04:	40d4      	str r2,[r0,0x1]
 b06:	194f 0402 	rts
*/

/* awful ! stalls !
.balign 8
inc64asm2:

  ldr r1,[r0]
  isub r2,r63,r63
  ldr r3,[r0,0x1]
  isub r1,r1,r63
  mov ip,0x1
  movbeq r2,r63
  str r1,[r0]
  sub r2,r3,r2
  str r2,[r0,0x1]
  rts
*/

// the shorter inc64 I can imagine (4 bytes less with removing the useless .l suffixes), and curiously a bit faster despite RA stalls
// assumes source is 8-byte aligned

.balign 8
inc64asm2:

  ldrd.l r2,[r0]
  isub ip,r63,r63
  sub r2,r2,r63
  movgteu ip,r63
  sub r3,r3,ip
  strd.l r2,[r0]
  rts
