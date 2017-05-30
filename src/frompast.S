.file	"borderwest.S"

.global Asm_Init
.global BorderWest
.global InnerTile
.global BorderEast
.global Special_H1
.global Special_I1
.global Special_H2

#define STATS // <!> the #define STATS inside the previous *.c does NOT propagate here in this assembly file <!>
#define STD_ALIGN8 .balignw 8, 0x01a2 // fine for data and for unreachable code
/*
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
*/

#define B1N   0
#define C1N  10
#define C2N  11
#define C3N  12
#define C4N  13
#define C5N  14
#define C6N  15
#define C7N  16
#define C8N  17
#define C9N  18
#define C10N 19

#define B1E   90
#define C1E   99
#define C2E  100
#define C3E  101
#define C4E  102
#define C5E  103
#define C6E  104
#define C7E  105
#define C8E  106
#define C9E  107

// first: no update registers
#define I_M1            r63 // -m1reg-r63 is a good initiative from Adapteva & the compiler guys :D
#define O_STATS         r62
#define O_T14T          r61 // asm volatile ("mov r57,%low(_t14T)\n");
#define O_T14E          r60 // asm volatile ("mov r56,%low(_t14E)\n");
#define O_T14S          r59 // asm volatile ("mov r55,%low(_t14S)\n");
#define O_TBORDURED     r58
#define O_TBORDUREG     r57
#define O_TBORDUREI     r56
#define O_TTILEN        r55 // const char ttileN[100]
#define O_B2016D        r54
#define O_B2016G        r53
#define O_B2016I        r52
#define O_FN            r51
#define O_TTILES        r50 // tmp.ttiles 
#define O_TPOPCOUNT     r49
#define O_TDEBRUIJN32   r48
#define O_WEST          r47 
#define O_NORTH         r46 

#define I_0             r28 // r28-31, EABI reserved area but unused until now
#define I_1             r29
#define I_4             r30
#define I_8             r31

#define I_10            r27
#define I_32            r26 // stack increment ; always choose a multiple of 8
#define I_255           r25
#define I_MULDEBRUIJN32 r24
#define I_2             r23

#define R_BORDERS       r45 // critical 32-bit value => to a register
#define S_TILEB         r44 // even register to ldrd/strd (8-byte push/pop)
#define R_PTR           r43 // critical 32-bit value => to a register // will point to next function (fn)
#define R_IDX           r42 // indexing 32-bit arrays


#define S_LR            lr  // lr is an alias for r14, sp for r13, fp for... er, r15 ? r12 ?


.text
STD_ALIGN8
Asm_Init:

  mov O_STATS ,%low(out)      
  mov O_T14T,%low(t14T)
  mov O_T14E,%low(t14E)
  mov O_T14S,%low(t14S)
  mov O_TBORDURED,%low(tbordureD)
  mov O_TBORDUREG,%low(tbordureG)
  mov O_TBORDUREI,%low(tbordureI)
  mov O_TTILEN,%low(ttileN)
/*
#define BORDERCOLOR_D 0
#define BORDERCOLOR_G 4
#define BORDERCOLOR_I 9
#define BORDERCOLOR_N 19 //19 border colors ; 1st is NULL, 1-4 for D, 5-8 for G, 9-18 for Inner
*/
  mov O_B2016D,%low(tlscouleur_B2016)
  mov O_B2016G,%low(tlscouleur_B2016 + 4 * 4)
  mov O_B2016I,%low(tlscouleur_B2016 + 9 * 4)
  mov O_FN,%low(tfncall)
  mov O_TTILES,%low(tmp + 4) // please anybody find the syntax for calling a member of a structure
  mov O_TPOPCOUNT,   %low(tcountbit)
  mov O_TDEBRUIJN32, %low(MultiplyDeBruijn32)
  
  mov I_0,   #0
  mov I_1,   #1
  mov I_4,   #4
  mov I_8,   #8
  mov I_10,  #10
  mov I_32,  #32 // stack increment
  mov I_255, #255
  mov  I_MULDEBRUIJN32,  %low(0x077CB531)
  movt I_MULDEBRUIJN32, %high(0x077CB531) // 0x077C

  // critical data
  mov r0,%low(in + 8) 
  ldr R_BORDERS, [ r0 ]      // bordertuile2do
  mov R_IDX, I_0             // need for pipeline # 2 ? => imul R_IDX, I_0
  ldr R_PTR, [ O_FN, R_IDX ]
  // north=C1N; west=C1E;
  mov O_WEST, %low(in + 8 + 4 + C1E)
  mov O_NORTH,%low(in + 8 + 4 + C1N)

// for test only !!!
// strb I_1, [ O_NORTH, #50 ] // H1N
// strb I_1, [ O_NORTH, #51 ] // H2N

  rts
  

.text // code section

/* LEARNED
// <!> idx is NOT multiplied by the ldr suffix <!>  => if u can, avoid INT64/32/16 and prefer INT8
// beq stands for x86 JZ  ; when tested on a IALU2 instruction, use bbeq
// bne stands for x86 JNZ ; when tested on a IALU2 instruction, use bbne
// <!> the LR must be preserved else you never exit from your recursive function lol ;
// JALR register: PC=register, LR=next_instruction => a good choice ; JR register is like an x86 JMP eax... know what u do
// my choice: sub sp, sp, N   and str lr, [sp, #-1] ... ldr lr, [sp, #-1] and add sp, sp, N  -- not caring about FP
*/

// tdam[C1N]=3, color=3, tileB=0xff8000, tileN=6
// only colorX8, lr, tile and tileN need to be recursively saved :D
// <!> SP must be 64-bit aligned !

// push/pop needed
#define tile     r32 // <!> packed even 64-bit register !
#define tileN    r33 //
#define colorX8  r34

// tmp, no push/pop
#define east     r16
#define south    r17
#define done     r18
#define color    r19
#define tmp0     r20

// <!> since Epiphany has only 2-byte or 4-byte instructions and allows jumping to any even address, minimal alignment is required
//     Though, the instruction fetcher can fetch a 8-byte aligned chunk of instruction code per clock cycle
// => better align to 8-byte after jumps and before functions

STD_ALIGN8
InnerTile:

  isub sp,sp,I_32 
  str S_LR, [sp, #1]

#ifdef STATS
  ldr tmp0, [ O_STATS, R_IDX ] 
  sub tmp0, tmp0, I_M1
  str tmp0, [ O_STATS, R_IDX ] 
#endif

  // color=in.tdam[west] + in.tdam[north] * 10;
  ldrb tmp0, [O_NORTH] 
  iadd R_IDX, R_IDX, I_4

  ldrb color,[O_WEST]
  imadd color, tmp0, I_10 // WAW stall
     
  ldrb tileN, [ O_TTILEN, color ]
  imul colorX8, color, I_8
    
  iadd tileN, tileN, I_0
  bbeq.l .L19 //bblt: < 0 ; bblte: <= 0 ; bbeq: == 0 ; bbne: != 0
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L10:

  isub tileN, tileN, I_1 // tileN--;
  ldrb tile, [ O_T14T, colorX8 ] // if(tmp.ttiles[tile] == 0) continue;
  
  ldrb east, [ O_T14E, colorX8 ]
  ldrb done, [ O_TTILES, tile ]
  ldrb south,[ O_T14S, colorX8 ]
  iadd colorX8, colorX8, I_1
  iadd done, done, I_0
  bbeq.l .L11

  strb east,  [ O_WEST,  I_1 ]
  strb south, [ O_NORTH, I_10 ]

  isub O_WEST,  O_WEST,  I_M1
  strb I_0, [ O_TTILES, tile ] // tmp.tiles[tile]=0;

  isub O_NORTH, O_NORTH, I_M1
  strd tile, [ sp, #1 ]

  ldr R_PTR, [ O_FN, R_IDX ]

  str colorX8, [ sp, #4 ]
  jalr R_PTR

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.Lalign14:
  
  ldr colorX8, [ sp, #4 ]
  iadd O_WEST, O_WEST,  I_M1

  ldrd tile,  [ sp, #1 ] // tile & tileN
  iadd O_NORTH, O_NORTH, I_M1

  strb I_1, [ O_TTILES, tile ] // tmp.tiles[tile]=1;
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L11:
  isub tileN, tileN, I_0 
  bbne.l .L10
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L19:

  isub R_IDX, R_IDX, I_4
  ldr S_LR, [sp, #1]

  iadd sp,sp,I_32
  rts

#undef color 
#undef tile  
#undef tileN 
#undef colorX8
#undef tmp0   

#undef east   
#undef south  
#undef done   


/* LEARNED
// <!> idx is NOT multiplied by the ldr suffix <!>  => if u can, avoid INT64/32/16 and prefer INT8
*/

// tmp
#define color   r16
#define tileN   r17
#define tmp0    r18 // or r32, possible double usage
#define tmp2    r19
#define tmp3    r20
#define tmp4    r21
#define tile    r22

STD_ALIGN8
// make our function callable -- help the linker or loader
BorderWest:

  isub sp,sp,I_32 // bordertuile2do, tileB
  
  str S_LR, [sp, #1] // RAW stall ; optim ? str ... #28 then isub sp,sp,I_32

#ifdef STATS
  ldr tmp0, [ O_STATS, R_IDX ] 
  sub tmp0, tmp0, I_M1
  str tmp0, [ O_STATS, R_IDX ] 
#endif

  iadd R_IDX, R_IDX, I_4
  str R_BORDERS, [sp, #3] // save=in.bordertuile2do;

  ldrb color, [O_NORTH] // <!> idx is NOT multiplied by the ldr suffix <!> 
  imul color, color, I_4
  ldr tmp0, [O_B2016G, color]
  and S_TILEB, R_BORDERS, tmp0
  beq.l .L2

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L0:
  // tile=Epiphany_ctz(tuileB);
  sub tile, I_0, S_TILEB  //v & -v
  and tile, tile, S_TILEB
  imul tile, tile, I_MULDEBRUIJN32
  lsr  tile, tile, #27
  ldrb tile, [O_TDEBRUIJN32, tile]

  // R_BORDERS^=(1U << tile);
  lsl tmp2, I_1, tile
  eor R_BORDERS, R_BORDERS, tmp2

  // in.tdam[west+1]=tbordureI[tile];
  // in.tdam[north+10]=tbordureD[tile];
  // in.bordertuile2do ^= (1U << tile);
  // north++; west++;
  
  ldrb tmp3, [ O_TBORDUREI, tile ]
  ldrb tmp4, [ O_TBORDURED, tile ]
  strb tmp3, [ O_WEST,  I_1 ]
  strb tmp4, [ O_NORTH, I_10 ]
  iadd O_WEST, O_WEST, I_1
  eor S_TILEB, S_TILEB, tmp2
  iadd O_NORTH, O_NORTH, I_1

  str S_TILEB, [sp, #2] // R_BORDERS is pushed only once... but popped each time

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
  ldr R_PTR, [ O_FN, R_IDX ]
  jalr R_PTR

  // north--; west--; pop(borders)

  isub O_WEST, O_WEST, I_1
  ldrd S_TILEB, [sp, #1] // restoring tileB and borders together

  sub O_NORTH, O_NORTH, I_1
  imul S_TILEB, S_TILEB, I_1

  bbne.l .L0 // bne == x86 JNZ ; bbne == for float... just test if for IALU2 too...
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L2:
  
  // useless, done by the loop already // ldr R_BORDERS, [sp, #0] // save=in.bordertuile2do;

  isub R_IDX, R_IDX, I_4
  ldr S_LR, [sp, #1] 
  iadd sp,sp,I_32

  // debug
  ldr r0, [ O_STATS,0 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r1, [ O_STATS,1 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r2, [ O_STATS,2 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r3, [ O_STATS,3 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r4, [ O_STATS,4 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r5, [ O_STATS,5 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r6, [ O_STATS,6 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r7, [ O_STATS,7 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r0, [ O_STATS,8 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r1, [ O_STATS,9 ] // debug... mov r0, tileN //tmp0 //tileB
  ldr r2, [ O_STATS,10] // debug... mov r0, tileN //tmp0 //tileB
  ldr r3, [ O_STATS,11] // debug... mov r0, tileN //tmp0 //tileB
  ldr r4, [ O_STATS,12] // debug... mov r0, tileN //tmp0 //tileB
  ldr r5, [ O_STATS,13] // debug... mov r0, tileN //tmp0 //tileB
  ldr r6, [ O_STATS,14] // debug... mov r0, tileN //tmp0 //tileB
  ldr r7, [ O_STATS,15] // debug... mov r0, tileN //tmp0 //tileB
  rts

#undef color
#undef tmp0 
#undef tile
#undef tileN
#undef tmp2
#undef tmp3
#undef tmp4



/* LEARNED
// <!> idx is NOT multiplied by the ldr suffix <!>  => if u can, avoid INT64/32/16 and prefer INT8
*/

// tmp
#define colorD  r16
#define colorI  r17
#define tmp0    r18 // or r32, possible double usage
#define tmp2    r19
#define tmp3    r20
#define tmp4    r21
#define tile    r22

STD_ALIGN8
// make our function callable -- help the linker or loader
BorderEast:

  isub sp,sp,I_32 // bordertuile2do, tileB
  
  str S_LR, [sp, #1] // RAW stall ; optim ? str ... #28 then isub sp,sp,I_32

#ifdef STATS
  ldr tmp0, [ O_STATS, R_IDX ] 
  sub tmp0, tmp0, I_M1
  str tmp0, [ O_STATS, R_IDX ] 
#endif

  iadd R_IDX, R_IDX, I_4
  str R_BORDERS, [sp, #3] // save=in.bordertuile2do;

/*
  DtuileB=tlscouleur_B2016[BORDERCOLOR_D + in.tdam[north]] & in.bordertuile2do;
  ItuileB=tlscouleur_B2016[BORDERCOLOR_I + in.tdam[west]] & in.bordertuile2do;
  tuileB= ItuileB & DtuileB;
*/
 
  ldrb colorD, [O_NORTH] 
  
  ldrb colorI, [O_WEST] 
  imul colorD, colorD, I_4

  imul colorI, colorI, I_4
  ldr tmp0, [O_B2016D, colorD]

  ldr tmp2, [O_B2016I, colorI]

  and S_TILEB, R_BORDERS, tmp0
  
  and S_TILEB, S_TILEB, tmp2
  
  beq.l .L22

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L20:
  // tile=Epiphany_ctz(tuileB);
  sub tile, I_0, S_TILEB  //v & -v
  and tile, tile, S_TILEB
  imul tile, tile, I_MULDEBRUIJN32
  lsr  tile, tile, #27
  ldrb tile, [O_TDEBRUIJN32, tile]

  // R_BORDERS^=(1U << tile);
  lsl tmp2, I_1, tile
  eor R_BORDERS, R_BORDERS, tmp2

  // compared to _BorderWest: no east output ; and O_TBORDUREG !
  // in.tdam[north+10]=tbordureG[tile];
  // in.bordertuile2do ^= (1U << tile);
  // north++; west++;
  
  ldrb tmp4, [ O_TBORDUREG, tile ]
  iadd O_WEST, O_WEST, I_1
  strb tmp4, [ O_NORTH, I_10 ]
  iadd O_NORTH, O_NORTH, I_1
  eor S_TILEB, S_TILEB, tmp2

  str S_TILEB, [sp, #2] // R_BORDERS is pushed only once... but popped each time

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
  ldr R_PTR, [ O_FN, R_IDX ]
  jalr R_PTR

  // north--; west--; pop(borders)

  isub O_WEST, O_WEST, I_1
  ldrd S_TILEB, [sp, #1] // restoring tileB and borders together

  sub O_NORTH, O_NORTH, I_1
  iadd S_TILEB, S_TILEB, I_0

  bbne.l .L20 // bne == x86 JNZ ; bbne == for float... just test if for IALU2 too...
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L22:
  
  isub R_IDX, R_IDX, I_4
  ldr S_LR, [sp, #1] 
  iadd sp,sp,I_32
  rts

#undef colorD
#undef colorI
#undef tmp0 
#undef tmp2
#undef tmp3
#undef tmp4
#undef tile



// tmp
#define color   r16
#define tileN   r17
#define tmp0    r18 // or r32, possible double usage
#define tmp2    r19
#define tmp3    r20
#define tmp4    r21
#define tile    r22
#define save    r8

STD_ALIGN8
Special_H1:
// _Special_H1(): 2 differences compared to _BorderWest() ; you compute tileB but save it for a 2nd round ; there are 2 rounds, each with J1N/J10/J1E/J9E customized

  isub sp,sp,I_32 // bordertuile2do, tileB
  
  str S_LR, [sp, #1] // RAW stall ; optim ? str ... #28 then isub sp,sp,I_32

#ifdef STATS
  ldr tmp0, [ O_STATS, R_IDX ] 
  sub tmp0, tmp0, I_M1
  str tmp0, [ O_STATS, R_IDX ] 
#endif

  iadd R_IDX, R_IDX, I_4
  str R_BORDERS, [sp, #3] // save=in.bordertuile2do;

  ldrb color, [O_NORTH] // <!> idx is NOT multiplied by the ldr suffix <!> 
  imul color, color, I_4
  ldr tmp0, [O_B2016G, color]
  and S_TILEB, R_BORDERS, tmp0
  beq.l .L32

  str S_TILEB, [sp, #4] // save tileB for a 2nd round
  
	/* 1st corner config //heavy customisation: corners 2 & 3 from brendan_pieces_10x10.txt 
  in.tdam[north + (2*10) + 0]=2;// J1N
  in.tdam[north + (2*10) + 9]=2;// J10N
  in.tdam[west  + (2*10) + 0]=4;// J1E
  in.tdam[west  + (2*10) + 8]=4;// J9E
  */
  strb I_4, [ O_WEST,  #20]
  strb I_2, [ O_NORTH, #20]
  strb I_4, [ O_WEST,  #28]
  strb I_2, [ O_NORTH, #29]
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L30:
  sub tile, I_0, S_TILEB  //v & -v
  and tile, tile, S_TILEB
  imul tile, tile, I_MULDEBRUIJN32
  lsr  tile, tile, #27
  ldrb tile, [O_TDEBRUIJN32, tile]

  lsl tmp2, I_1, tile
  eor R_BORDERS, R_BORDERS, tmp2

  ldrb tmp3, [ O_TBORDUREI, tile ]
  ldrb tmp4, [ O_TBORDURED, tile ]
  strb tmp3, [ O_WEST,  I_1 ]
  strb tmp4, [ O_NORTH, I_10 ]
  iadd O_WEST, O_WEST, I_1
  eor S_TILEB, S_TILEB, tmp2
  iadd O_NORTH, O_NORTH, I_1

  str S_TILEB, [sp, #2] 

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
  ldr R_PTR, [ O_FN, R_IDX ]
  jalr R_PTR

  isub O_WEST, O_WEST, I_1
  ldrd S_TILEB, [sp, #1] // restoring tileB and borders together

  sub O_NORTH, O_NORTH, I_1
  imul S_TILEB, S_TILEB, I_1

  bbne.l .L30 // bne == x86 JNZ ; bbne == for float... just test if for IALU2 too...

// 2nd round
  ldr S_TILEB, [sp, #4]
  strb I_2, [ O_WEST,  #20]
  strb I_4, [ O_NORTH, #20]
  strb I_2, [ O_WEST,  #28]
  strb I_4, [ O_NORTH, #29]

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L33:
  sub tile, I_0, S_TILEB  //v & -v
  and tile, tile, S_TILEB
  imul tile, tile, I_MULDEBRUIJN32
  lsr  tile, tile, #27
  ldrb tile, [O_TDEBRUIJN32, tile]

  lsl tmp2, I_1, tile
  eor R_BORDERS, R_BORDERS, tmp2

  ldrb tmp3, [ O_TBORDUREI, tile ]
  ldrb tmp4, [ O_TBORDURED, tile ]
  strb tmp3, [ O_WEST,  I_1 ]
  strb tmp4, [ O_NORTH, I_10 ]
  iadd O_WEST, O_WEST, I_1
  eor S_TILEB, S_TILEB, tmp2
  iadd O_NORTH, O_NORTH, I_1

  str S_TILEB, [sp, #2] 

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
  ldr R_PTR, [ O_FN, R_IDX ]
  jalr R_PTR

  isub O_WEST, O_WEST, I_1
  ldrd S_TILEB, [sp, #1] // restoring tileB and borders together

  sub O_NORTH, O_NORTH, I_1
  imul S_TILEB, S_TILEB, I_1

  bbne.l .L33 // bne == x86 JNZ ; bbne == for float... just test if for IALU2 too...

  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L32:

// useless: done in each loop actually // ldr R_BORDERS, [sp, #0] // save=in.bordertuile2do;
  
  isub R_IDX, R_IDX, I_4
  ldr S_LR, [sp, #1] 

  iadd sp,sp,I_32
  rts

#undef save
#undef color
#undef tmp0 
#undef tile
#undef tileN
#undef tmp2
#undef tmp3
#undef tmp4




// tmp
#define colorG  r16
#define colorD  r17
#define tmp0    r18 // or r32, possible double usage
#define tmp2    r19
#define tmp3    r20
#define tmp4    r21
#define tile    r22


STD_ALIGN8
// make our function callable -- help the linker or loader
Special_I1:
// 2 differences compared to _BorderWest(): no south to update since it's already in place ; therefore an initial double test for S_TILEB

  isub sp,sp,I_32 // bordertuile2do, tileB
  
  str S_LR, [sp, #1] // RAW stall ; optim ? str ... #28 then isub sp,sp,I_32

#ifdef STATS
  ldr tmp0, [ O_STATS, R_IDX ] 
  sub tmp0, tmp0, I_M1
  str tmp0, [ O_STATS, R_IDX ] 
#endif

  iadd R_IDX, R_IDX, I_4
  str R_BORDERS, [sp, #3] // save=in.bordertuile2do;

  // tuileB=tlscouleur_B2016[BORDERCOLOR_G + in.tdam[north]] & tlscouleur_B2016[BORDERCOLOR_D + in.tdam[north+10]] & in.bordertuile2do;

  ldrb colorG, [O_NORTH] 

  ldrb colorD, [O_NORTH, #10] 
  imul colorG, colorG, I_4

  imul colorD, colorD, I_4
  ldr colorG, [O_B2016G, colorG]
  
  ldr colorD, [O_B2016D, colorD]
  
  and S_TILEB, R_BORDERS, colorG

  and S_TILEB, S_TILEB,   colorD
  beq.l .L42

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L40:
  // tile=Epiphany_ctz(tuileB);
  sub tile, I_0, S_TILEB  //v & -v
  and tile, tile, S_TILEB
  imul tile, tile, I_MULDEBRUIJN32
  lsr  tile, tile, #27
  ldrb tile, [O_TDEBRUIJN32, tile]

  // R_BORDERS^=(1U << tile);
  lsl tmp2, I_1, tile
  eor R_BORDERS, R_BORDERS, tmp2

  // in.tdam[west+1]=tbordureI[tile];
  // in.bordertuile2do ^= (1U << tile);
  // north++; west++;
  
  ldrb tmp3, [ O_TBORDUREI, tile ]
  strb tmp3, [ O_WEST,  I_1 ]
  iadd O_WEST, O_WEST, I_1
  eor S_TILEB, S_TILEB, tmp2
  iadd O_NORTH, O_NORTH, I_1

  str S_TILEB, [sp, #2] // R_BORDERS is pushed only once... but popped each time

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
  ldr R_PTR, [ O_FN, R_IDX ]
  jalr R_PTR

  // north--; west--; pop(borders)

  isub O_WEST, O_WEST, I_1
  ldrd S_TILEB, [sp, #1] // restoring tileB and borders together

  sub O_NORTH, O_NORTH, I_1
  imul S_TILEB, S_TILEB, I_1

  bbne.l .L40 // bne == x86 JNZ ; bbne == for float... just test if for IALU2 too...
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L42:
  
  isub R_IDX, R_IDX, I_4
  ldr S_LR, [sp, #1] 

  iadd sp,sp,I_32
  rts

#undef colorD
#undef colorG
#undef tile
#undef tmp0 
#undef tmp2
#undef tmp3
#undef tmp4


// push/pop needed
#define tile     r32 // <!> packed even 64-bit register !
#define tileN    r33 //
#define colorX8  r34

// tmp, no push/pop
#define east     r16
#define south    r17
#define done     r18
#define color    r19
#define tmp0     r20
#define anticipatedcolor r21
#define colorD   r22
#define colorG   r10

STD_ALIGN8
Special_H2:
// Special_H2() is like InnerTile() with 1 difference: anticipatedcolor cutoff

  isub sp,sp,I_32 
  str S_LR, [sp, #1]

#ifdef STATS
  ldr tmp0, [ O_STATS, R_IDX ] 
  sub tmp0, tmp0, I_M1
  str tmp0, [ O_STATS, R_IDX ] 
#endif

  // anticipatedcolor=tlscouleur_B2016[BORDERCOLOR_G + in.tdam[north+9]] & tlscouleur_B2016[BORDERCOLOR_D + in.tdam[north+19]] & in.bordertuile2do;
  // ifz(anticipatedcolor) goto fin;

  ldrb colorG, [O_NORTH, #9] 

  ldrb colorD, [O_NORTH, #19] 
  imul colorG, colorG, I_4

  imul colorD, colorD, I_4
  ldr colorG, [O_B2016G, colorG]
  
  ldr colorD, [O_B2016D, colorD]
  
  and anticipatedcolor, R_BORDERS, colorG

  and anticipatedcolor, anticipatedcolor, colorD

  beq.l .L59shortcut

  // color=in.tdam[west] + in.tdam[north] * 10;
  ldrb tmp0, [O_NORTH] 
  iadd R_IDX, R_IDX, I_4

  ldrb color,[O_WEST]
  imadd color, tmp0, I_10 // WAW stall
     
  ldrb tileN, [ O_TTILEN, color ]
  imul colorX8, color, I_8
    
  iadd tileN, tileN, I_0
  bbeq.l .L59 //bblt: < 0 ; bblte: <= 0 ; bbeq: == 0 ; bbne: != 0
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L50:

  isub tileN, tileN, I_1 // tileN--;
  ldrb tile, [ O_T14T, colorX8 ] // if(tmp.ttiles[tile] == 0) continue;
  
  ldrb east, [ O_T14E, colorX8 ]
  ldrb done, [ O_TTILES, tile ]
  ldrb south,[ O_T14S, colorX8 ]
  iadd colorX8, colorX8, I_1
  iadd done, done, I_0
  bbeq.l .L51

  strb east,  [ O_WEST,  I_1 ]
  strb south, [ O_NORTH, I_10 ]

  isub O_WEST,  O_WEST,  I_M1
  strb I_0, [ O_TTILES, tile ] // tmp.tiles[tile]=0;

  isub O_NORTH, O_NORTH, I_M1
  strd tile, [ sp, #1 ]

  ldr R_PTR, [ O_FN, R_IDX ]

  str colorX8, [ sp, #4 ]
  jalr R_PTR

.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
  
  ldr colorX8, [ sp, #4 ]
  iadd O_WEST, O_WEST,  I_M1

  ldrd tile,  [ sp, #1 ] // tile & tileN
  iadd O_NORTH, O_NORTH, I_M1

  strb I_1, [ O_TTILES, tile ] // tmp.tiles[tile]=1;
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L51:
  isub tileN, tileN, I_0 
  bbne.l .L50
  
.balignw 4, 0x01a2 // PERFECT_ALIGN8
.balignl 8, 0xfc02fcef
.L59:

  isub R_IDX, R_IDX, I_4
.L59shortcut:
  ldr S_LR, [sp, #1]

  iadd sp,sp,I_32
  rts

#undef color 
#undef tile  
#undef tileN 
#undef colorX8
#undef tmp0   
#undef anticipatedcolor
#undef colorD
#undef colorG

#undef east   
#undef south  
#undef done   



/*
  inc64(x) in 6 ic a priori  :)  Better than gcc 4.8.2


// gcc explorer with compiler options: 
// -T /home/ylav/dev/parallella/epiphany-libs-2015.1/bsps/current/internal.ldf -Ofast -le-lib -mfp-mode=int  -m1reg-r63
// (e-gcc (Epiphany toolchain 2015.1) 4.8.2 20130729 (prerelease))

// #include <e-lib.h> //mandatory even for a minimalist design -- e_get_coreid(), e_read(), e_write()

signed long long  test;

void add64(signed long long *count, signed long long a) {
  (*count) += a;
}

void inc64(signed long long *count) {
  (*count)++;
}


Output:
[add64]
        ldr r1,[r0]
        ldr r16,[r0,#1]
        add r1,r1,r2
        mov ip,#0
        mov r2,#1
        movgteu ip,r2
        add r3,r16,r3
        add ip,ip,r3
        str r1,[r0]
        str ip,[r0,#1]
        rts

[inc64]
        ldr r2,[r0]
        ldr r3,[r0,#1]
        sub r2,r2,#-1
        mov r1,#0
        mov ip,#1
        movgteu r1,ip
        add r1,r1,r3
        str r2,[r0]
        str r1,[r0,#1]
        rts


My suggestion for inc64(var):
// -Ofast -mfp-mode=int -m1reg-r63
// IN: r0 = offset(var)
// OUT: updated var
// TMP: r1, r2, r3

        ldrd r2,[r0]
        isub r1, r63, r63
        sub  r2, r2,  r63
        moveq r1, r63
        isub  r3, r3, r1
        strd r2, [r0]

*/

//from e-fft-asm.S

/* Macro for easy hw loop setup */
.macro hwloop start, end, tmp_reg
	mov	\tmp_reg, %low(\start)
	movts	ls, \tmp_reg

	mov	\tmp_reg, %low(\end - 4)
	movts	le, \tmp_reg
.endm

.macro bibi start, end, tmp1, tmp2
	mov	\tmp1, %low(\start)
	mov	\tmp2, %low(\end)
  sub \tmp2, \tmp2, \tmp1
.if ((\end) - (\start)) % 8 == 2  
  mov r50, #2
.elseif ((\end) - (\start)) % 8 == 4
  mov r50, #4
.elseif ((\end) - (\start)) % 8 == 6
  mov r50, #6
.endif  
.endm

.text
gid
.balignw 8, 0x01a2
hwloop 1f, 2f, r3
1:
  mov.l r0,r63
  mov.l r0,r63
  mov.l r0,r63
  mov.l r0,r63
  mov.l r0,r63
  bibi 6, 8, r49, r48
  mov.l r0,r63
  mov.l r0,r63
  mov.l r0,r63
  mov.l r0,r63
  mov.l r0,r63
2:
  gie
  rts


/* 
  assembly with no alignment harassment ?
  
  it would be so easy with 32-bit instructions only ; but 16-bit instructions exist too.
  Well, it's not so difficult avoiding the latter... just follow these THREE conditions:
    - avoid "system" instructions: GID GIE NOP IDLE BKPT MBKPT SYNC RTI WAND TRAP UNIMPL
    - for B<cond> instructions, use the long format B<cond><simm24> and never B<cond><simm8>
    - for other instructions,  never use r0-r7 as exclusive registers. r8-r63 will force the 32-bit instruction mode ; so do >= SIMM11 operands.
    
  => in practice, just use a macro to force the B<cond><simm24> encoding :D  the suffix ".l" is enough ; example: beq.l label  ; mov.l r0, #1
*/
