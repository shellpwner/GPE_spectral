default: run

run: 
	ifort -lfftw3 src/spectral_1d.f90
	./a.out
	rm *mod
	mv *txt out
	mv a.out out
clean:
	rm -rf  out/*.txt
	rm -rf  out/a.out
