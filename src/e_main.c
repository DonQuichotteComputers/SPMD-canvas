#include "e-lib.h" // mandatory even for a minimalist design -- e_get_coreid(), e_read(), e_write()
#include "C_common.h" // common definitions for C

#define ALWAYS_INLINE inline __attribute__((always_inline))

ALWAYS_INLINE unsigned _e_get_ctimer0() {
  register unsigned tmp asm("r0");
  asm volatile ("movfs %0, ctimer0;" : "=r" (tmp) :: );
  return tmp;
}

ALWAYS_INLINE unsigned _e_get_ctimer1() {
  register unsigned tmp asm("r0");
  asm volatile ("movfs %0, ctimer1;" : "=r" (tmp) :: );
  return tmp;
}

#include "common.h"   // common definitions for your specific project

//#######################################
//INPUT/OUTPUT DATA

/* previous code was:
    
   volatile Sinput  in  SECTION(".data_bank3"); // SHARED_IN
   volatile Soutput out SECTION(".data_bank3"); // SHARED_OUT
  
  this way of coding is BAD: the linker will NOT necessarily place 'in' at offset 0x6000 and 'out' just AFTER 'in' (actually it places 'out' BEFORE 'in' !)
  
   => ONE reliable way of coding is ONE structure for exchanging with the rest of the world
*/

volatile Sio  io  SECTION(".data_bank3"); // other said: the local offset 0x6000

#define in  io.in  // as my math teacher always said: be good, be lazy
#define out io.out

//#######################################

Stmp    tmp;

//#######################################
//THE 'COMPUTE KERNEL'

void Your_Functions_Here(const int, const int);
// void __attribute__ ((noinline)) Input_Copy(int, int *);

//#######################################
//STATIC DATA

//typedef void (*ptrFonction) (const signed int, const signed int);

ALIGN(8)
void (* tfncall[78]) (const int, const int) ={
   Your_Functions_Here,
};

//dynamic data
// int tborderwestN[4]={0};

void Your_Functions_Here(const int north, const int northI) {
  // out.something--;
}

//#######################################

// prevent inlining this trivial function: we may need some room
void __attribute__ ((noinline)) Input_Copy(int tiles, int *dest) {
  int fn1;
  LOOP1(32) {
    // dest[fn1]=tiles & 1;
    // tiles>>=1;
  }
}

//void __attribute__((interrupt)) null_isr() { return; }

int __attribute__ ((noinline)) Iamthebest(int a, int b) {
  return a+b;
}

int __attribute__ ((noinline)) Iamthebest2(int a, int b) {
  return b+a;
}

void __attribute__ ((noinline)) inc64(signed long long *count) {
  (*count)++;
}

void __attribute__ ((noinline)) inc64asm(signed long long *count); // see e_emain.S for the asm code
void __attribute__ ((noinline)) inc64asm2(signed long long *count); // see e_emain.S for the asm code

//#######################################

int main(void) {
e_start:;
  
  int64_t l1;
  int fn1, tiles;
  int time_start0, time_end0;
  
  volatile signed int *inputP  = (void *)SHARED_IN;  // pointer for input
  //volatile signed int *cmdP    = (void *)SHARED_CMD; // pointer for output command

  // init compute kernel
  // tiles=*(inputP+0); Input_Copy(tiles, &tmp.ttiles[ 0]); // 1st 32 tiles
  // tiles=*(inputP+1); Input_Copy(tiles, &tmp.ttiles[32]);
  // tiles=*(inputP+2); Input_Copy(tiles, &tmp.ttiles[VOIDTILE+1]); // 32 borders
    
  // each core has its own timers ?! yes
  e_ctimer_set(E_CTIMER_0, E_CTIMER_MAX);
  e_ctimer_start(E_CTIMER_0, in.timer0);

  // evaluate init cost
  time_start0=_e_get_ctimer0();
  time_end0=_e_get_ctimer0();
  out.timer0=time_start0 - time_end0; // parallella is ticking down

  // <---- your code to compare comes HERE
  // small difference with 1st run, so you should not rely on it.
  time_start0=_e_get_ctimer0();
  out.tres[0]=Iamthebest(*(inputP+2), *(inputP+3));
  out.ttimer0[0]=time_start0 - _e_get_ctimer0();
    
  time_start0=_e_get_ctimer0();
  out.tres[1]=Iamthebest(*(inputP+2), *(inputP+3));
  out.ttimer0[1]=time_start0 - _e_get_ctimer0();
    
  time_start0=_e_get_ctimer0();
  out.tres[2]=Iamthebest(*(inputP+2), *(inputP+3));
  out.ttimer0[2]=time_start0 - _e_get_ctimer0();
    
  time_start0=_e_get_ctimer0();
  out.tres[3]=Iamthebest(*(inputP+2), *(inputP+3));
  out.ttimer0[3]=time_start0 - _e_get_ctimer0();
    
  time_start0=_e_get_ctimer0();
  out.tres[4]=Iamthebest2(*(inputP+2), *(inputP+3));
  out.ttimer0[4]=time_start0 - _e_get_ctimer0();
    
  l1=*(int64_t *)(inputP+2);  
  time_start0=_e_get_ctimer0();
  inc64(&l1);
  out.ttimer0[5]=time_start0 - _e_get_ctimer0();
  *(int64_t *)(&out.tres[2])=l1;
    
  l1=*(int64_t *)(inputP+2);  
  time_start0=_e_get_ctimer0();
  inc64asm(&l1);
  out.ttimer0[6]=time_start0 - _e_get_ctimer0();
  *(int64_t *)(&out.tres[4])=l1;
  
  l1=*(int64_t *)(inputP+2);  
  time_start0=_e_get_ctimer0();
  inc64asm2(&l1);
  out.ttimer0[7]=time_start0 - _e_get_ctimer0();
  *(int64_t *)(&out.tres[6])=l1;
  // <---- your code to compare ends  HERE
  
  out.cmd=CMD_DONE; // *cmdP=CMD_DONE;
  __asm__ __volatile__ ("idle"); // experience: can you idle an Epiphany core until ARM wakes it up ?  Answer: empirically, yes ; use e_start() to reload the core
  //goto e_start; // wake by IVT # 0
}
