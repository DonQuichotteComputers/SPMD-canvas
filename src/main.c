#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <inttypes.h>
#include <e-hal.h> // HOST side ; mandatory

#include "C_common.h"  // common definitions for C

#define MY_EPIPHANY_ELF "bin/e_main.elf"
#define MY_DELAY_ESTIMATION 0

#include "common.h"    // common definitions for your project

//#######################################

void Epiphany_Boot(e_platform_t *epiphany) {
  e_init(NULL); // initialise the system, establish connection to the device
  e_reset_system(); // reset the Epiphany chip
  e_get_platform_info(epiphany);// get the configuration info for the parallella platform
}

//#######################################

const char ttimereventmsg[16][32]={
  { "E_CTIMER_OFF" },
  { "E_CTIMER_CLK" },
  { "E_CTIMER_IDLE" },
  { "E_CTIMER_64BIT" }, // do NOT use unless Parallella 64 or +
  { "E_CTIMER_IALU_INST" },
  { "E_CTIMER_FPU_INST" },
  { "E_CTIMER_DUAL_INST" },
  { "E_CTIMER_E1_STALLS" },
  { "E_CTIMER_RA_STALLS" },
  { "WHO_CARES" },
  { "WHO_CARES" },
  { "WHO_CARES" },
  { "E_CTIMER_EXT_FETCH_STALLS" },
  { "E_CTIMER_EXT_LOAD_STALLS" },
  { "WHO_CARES" },
  { "WHO_CARES" }
};
#define TIMER_EVENT_N 9
const int ttimereventI[TIMER_EVENT_N]={ 1, 2, 4, 5, 6, 7, 8, 12, 13 };

const char ttimereventmsg_short[16][8]={
  { "OFF" },
  { "CLK" },
  { "IDLE" },
  { "64BIT" }, // do NOT use unless Parallella 64 or +
  { "IALU" },
  { "FPU" },
  { "DUAL" },
  { "E1!" },
  { "RA!" },
  { "NIET" },
  { "NIET" },
  { "NIET" },
  { "FETCH!" },
  { "LOAD!" },
  { "NIET" },
  { "NIET" }
};

//#######################################

void usage(void) {
  uint fn1;
  
  printf("Usage:  the 8 1st parameters may be some input value for any benchmark\n\n");
  printf("  Insert your code to profile inside e_main.c\n\n");
  printf("  Each core implements one of the %u specific timer events listed below\n\n  %-32sCode\n\n",  TIMER_EVENT_N, "Timer event");
  
  LOOP1(TIMER_EVENT_N)
    printf("  %-32s%2u\n", ttimereventmsg[ttimereventI[fn1]], ttimereventI[fn1]);

//#######################################

/* from the esdk doc, enum type e_ctimer_config_t:

typedef enum {
E_CTIMER_OFF,
E_CTIMER_CLK,
E_CTIMER_IDLE,
E_CTIMER_IALU_INST,
E_CTIMER_FPU_INST,
E_CTIMER_DUAL_INST,
E_CTIMER_E1_STALLS,
E_CTIMER_RA_STALLS,
E_CTIMER_EXT_FETCH_STALLS,
E_CTIMER_EXT_LOAD_STALLS,
} e_ctimer_config_t;

#define E_CTIMER_MAX
*/

  pf("\nTry these arguments: -1 0 to test a 64-bit incrementation benchmark\n");

  exit(0);

}

//#######################################

int main(int argc, char *argv[]) {

  // Epiphany input/output through shared RAM ; details: common.h
  Sio     fromio;//Sio *fromio=(Sio *)malloc(sizeof(Sio));
  int row, col;
  e_platform_t epiphany;// Epiphany platform configuration
	e_epiphany_t dev;
  int tdata[16]={0};
  int tsummary[16][16*2]={{0}};
  
  int64_t l1=0;
	int i, j, fn1, fn2, timer0;
  uint64_t done=0;

  // pf("sz(io) = %u\n", sizeof(Sio));

  printf("\n\nCanvas for your SPMD project with configurable event timer stats :) \n\n\n");
	print("Don't forget to customize MY_EPIPHANY_ELF, that's useful for the 'e_load_group' line with YOUR Epiphany elf file !\n");
  
  if(argc > 1) {
    i=argc; if(argc >= 9) i=9;
    for(fn1=1; fn1<i; fn1++)
      tdata[fn1-1]=atoi(argv[fn1]);
  }
  else 
    usage();
    
  Epiphany_Boot(&epiphany);

	// Create a workgroup using all of the cores	
	e_open(&dev, 0, 0, epiphany.rows, epiphany.cols);
	e_reset_group(&dev);
	// Load the device code into each core of the chip, and don't start it yet
	e_load_group(MY_EPIPHANY_ELF, &dev, 0, 0, epiphany.rows, epiphany.cols, E_FALSE);

	// Set the maximum per core test value on each core at address 0x7020
	i=0;
  for(row=0;row<epiphany.rows;row++) {
		for(col=0;col<epiphany.cols;col++) {
      // init input/output
      fromio.out.cmd=CMD_INIT;
      LOOP1(8) fromio.in.tdata[fn1]=tdata[fn1];
      LOOP1(8) fromio.out.ttimer0[fn1]=0;
      fromio.in.mastercore=row * epiphany.rows + col;
      fromio.in.timer0=ttimereventI[fromio.in.mastercore % TIMER_EVENT_N];
      pf("i %u ; timer: %u\n", i, fromio.in.timer0);
      
			e_write(&dev, row, col, SHARED_IN, &fromio, sizeof(Sio));
      pf("i %u ; in written ; timer %u\n", i, fromio.in.timer0);
      i++;
		}
	}

	// Start all of the cores
  pf("Starting the core workgroup...\n\n");
	e_start_group(&dev);
  pf("... core workgroup started ; the whole test will last about %u second(s)...\n\n", MY_DELAY_ESTIMATION);

	while(1) {
		usleep(100000);
    //pf("fromio.out.cmd: 0x%08X\n", fromio.out.cmd);

		// wait for the cores to complete their work
		i=0;
    for(row=0;row<epiphany.rows;row++) {
			for(col=0;col<epiphany.cols;col++) {
        timer0=ttimereventI[i % TIMER_EVENT_N];
				if(e_read(&dev, row, col, SHARED_CMD, &fromio.out.cmd, sizeof(uint)) != sizeof(uint))
					fprintf(stderr, "\n\nFailed to read\n\n\n");

				if ( fromio.out.cmd != CMD_INIT) { //== CMD_DONE) {
          done |= (1ULL << i);
          if(e_read(&dev, row, col, SHARED_OUT, &fromio.out, sizeof(Soutput)) != sizeof(Soutput))
            fprintf(stderr, "\n\nFailed to read 2\n\n\n");
          pf("Timer 0 raw init: %9u occ.  %32s, event # %2u ; core %4u, cmd 0x%08X\n", fromio.out.timer0, ttimereventmsg[timer0], timer0, i, fromio.out.cmd);
          LOOP1(8) pf("  Timer 0, try # %u: %u ; , output 0x%08X\n", fn1, fromio.out.ttimer0[fn1], fromio.out.tres[fn1]); 
          print
          
          LOOP1(8) {
            tsummary[timer0][fn1*2+0]=fromio.out.ttimer0[fn1];
            tsummary[timer0][fn1*2+1]=fromio.out.tres[fn1];
          }
          
/* if u need to reset a core, use e_start(&dev, row, col) instead of the obsolete e_reset_core(&dev, row, col) ; early 2017 esdk doc is NOT uptodate with this.
          fromio.out.cmd=CMD_INIT;
          // etc
          e_write(&dev, row, col, SHARED_IN, &fromio, sizeof(Sio));
          pf("i %u ; in written again\n", i);
          e_start(&dev, row, col);
*/
        }
          
        i++;
			}
		}

		if ( done == 0xFFff ) // for Epiphany 3 only ; some benchmarks may be lengthy ; put some limits if u like
			break;
	}


	e_finalize();
  
  printf("\nResults summary\n\n");
  printf("Try #   ");
  print
  LOOP2(8) {
    pf("%6u  ", fn2);
    LOOP1(TIMER_EVENT_N) {
      timer0=ttimereventI[fn1];
      printf("%6d ", tsummary[timer0][fn2*2 + 1]);
    }
    print
  }

  printf("\nPerformance summary\n\n");
  printf("Try #   ");
  LOOP1(TIMER_EVENT_N) {
    timer0=ttimereventI[fn1];
    printf("%6s ", ttimereventmsg_short[timer0]);
  }
  print
  LOOP2(8) {
    pf("%6u  ", fn2);
    LOOP1(TIMER_EVENT_N) {
      timer0=ttimereventI[fn1];
      printf("%6u ", tsummary[timer0][fn2*2 + 0]);
    }
    print
  }
  
  
  printf("That's all folks !\n");
  
	return 0;
}
