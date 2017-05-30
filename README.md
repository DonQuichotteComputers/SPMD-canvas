# A canvas for writing SPMD (Single Program Multiple Data) as simple as possible -- no SDK at all.
# With configurable event timers.

## Build and Run

 Adapt the C source code to your needs ; place it in the subdirectory ./src
 Replace any batch value of "PGM" with your program name, example "main"
 
 ./build.sh
 ./run.sh [event_timer0] [event_timer1] [add_what_u_want]

 Cross compiling for an x86_64 platform ? You can use ./x86*.sh  
 Wanting to compile assembly ? You can use ./x86_buildasm.sh  

 ***
 
 Thas was for the 20170529 zip.
 Better use the 20170529b zip for a more exhaustive canvas:
 ./build.sh
 ./run.sh [your random data]

 - ANY event timer is used and reported in parallel
 - you place similar C functions inside e_main.c to compare them
 - custom data coming from main.c, the compiler cannot do some early and erroneous optimisations

 And better use the 20170529c zip for a canvas possibly including your asm routines :)
 
## Author

DonQuichotteComputers at gmail dot com
2017

## License

Don't be evil.
