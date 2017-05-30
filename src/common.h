// 2017/01/29: canvas for SPMD with configurable event timers
//   What to avoid: ELF support instead of SREC. No more UNsigned integers, no more char loads.

//   Expected usage: profile some code. Get input data from Sinput so as the compiler is unable to pre-optimize the e_main.c code.

#define CORE_N 16       //change it if needed ; our choice for standard 16-core Epiphany
#define MAX_CORE_N 1024 //Epiphany V ready ;)

// specific to the project
#define TMP_SPECIFIC 90

// to DEVICE
#pragma pack(4)
typedef struct S_input {
  int timer0;
  int mastercore; // or use the ad hoc library 
	int tdata[8]; 
}Sinput;

// from DEVICE
typedef struct S_output {
  int cmd;
  int timer0;
  int dummy;
  int dummy2;
  int tres[8];
  int ttimer0[8];
}Soutput;

// for shared MEMORY
typedef struct S_io {
  Sinput  in;
  Soutput out;
}Sio;

// tmp variables for DEVICE, trying a workaround for the -msmall16 compilation option
typedef struct S_tmp {
  int twhatever_you_want[TMP_SPECIFIC];
}Stmp;

// global offset for shared RAM
#define SHARED_RAM (0x01000000)

// a whole forum post for that
#define PERFECT_ALIGN8 __asm__ (".balignw 4, 0x01a2\n"); __asm__ (".balignl 8, 0xfc02fcef\n");

// Epiphany local offsets
#define SHARED_IN  0x6000
#define SHARED_OUT (SHARED_IN  + sizeof(Sinput))
#define SHARED_CMD SHARED_OUT

// commands for the Epiphany core
#define CMD_INIT 0x80000000 // host init (host = the ARM core)
#define CMD_DONE 0x40000000 // eCore output ; this Epiphany core did the job properly
