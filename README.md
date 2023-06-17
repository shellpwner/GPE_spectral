# GPE_spectral
Frotran90 codes to solve the Gross Pitaevsii equation using spectral methods.

The code in the file src/spectral_1d.f90 solves a version of the Gross-Pitaevskii equation. 
The initial seed wave function given to it is a simple gaussian pulse.  We used a fourier method to solve the NLSE.
We solve the equation in two steps. First the non derivative part of the equation is progressed in time, to arrive 
at an intermediate solution. Then this is used as an initial value for solving the derivative part using fourier methods.
