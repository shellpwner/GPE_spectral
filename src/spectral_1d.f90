MODULE COMM_DATA
  INTEGER, PARAMETER :: N = 2 * 2048 * 2, N2 = N/2      ! N : Number of space mesh points
  INTEGER, PARAMETER :: NRUN = 100000
  REAL (8), PARAMETER :: PI = 3.14159265358979D0
  REAL (8), PARAMETER :: LX = 20.48D0 * 2 * 2
END MODULE COMM_DATA

MODULE GPE_DATA
  USE, INTRINSIC :: ISO_C_BINDING
        
  USE COMM_DATA, ONLY : N, PI
  REAL (8), PARAMETER :: AHO = 1.D-6             		! Unit of length ( l = 1 MICRON)            
  REAL (8), PARAMETER :: Bohr_a0 =  5.2917720859D-11/AHO        ! Bohr radius (scaled with AHO)
  COMPLEX (8), PARAMETER :: CI = (0.D0,1.D0)           		! Complex i
!
  REAL (8), PARAMETER :: DX = 0.01D0, DT = 0.0001D0     	! DX : Space step and DT : Time step
  INTEGER, PARAMETER  :: NATOMS = 2000                  	! Number of Atoms
  REAL (8), PARAMETER :: AS = 74.1032482D0*Bohr_a0      	! Scattering length (in units of Bohr_a0)
  REAL (8), PARAMETER :: GAMMA = 1.D0                   	! Parameter of Trap
  REAL (8), PARAMETER :: DRHO = 0.5D0, DRHO2 = DRHO * DRHO      ! DRHO = AH0/SQRT(LAMBDA*KAPPA) : Transverse trap parameter 
!
  !REAL (8), PARAMETER :: G_1D = 4.D0*PI*AS*NATOMS/(2.D0*PI*DRHO2) ! G_1D : Nonlinearity in the one-dimensional GP equation
  REAL (8), PARAMETER :: G_1D = 1.0D0
  REAL (8), PARAMETER :: G32 = G_1D * SQRT(G_1D)
  REAL (8), PARAMETER :: DG = 0.5D0
  REAL (8), PARAMETER :: G_3D = G_1D*2.D0*PI*DRHO2      ! G_3D : Three-dimensional nonlinearity 
  REAL (8), PARAMETER :: GPAR = 0.5D0                 ! Change for dynamics
!
! OPTION   decides which equation to be solved.
! OPTION=1 Solves -psi_xx+V(x)psi+G_1D|psi|^2 psi =i psi_t
! OPTION=2 Solves [-psi_xx+V(x)psi]/2+G_1D|psi|^2 psi =i psi_t
  INTEGER, PARAMETER :: OPTION = 2 
!
  REAL (8), DIMENSION(N) :: X, X2
  COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(N) :: CP, CPF
  
  REAL (8) :: G,  GSTP,   XOP
END MODULE GPE_DATA

PROGRAM GP_SSF_1D
	USE, INTRINSIC :: ISO_C_BINDING
	USE GPE_DATA
	USE COMM_DATA
	IMPLICIT NONE
	INCLUDE 'fftw3.f03'
	!--------------INTERFACE BLOCKS----------------------
	INTERFACE
		SUBROUTINE INITIALIZE(CP, K)
			USE, INTRINSIC :: ISO_C_BINDING
			IMPLICIT NONE
			COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(1:), INTENT(INOUT) :: CP
			REAL (8), DIMENSION(1:), INTENT(INOUT) :: K
		END SUBROUTINE INITIALIZE
	END INTERFACE
	
	INTERFACE
		SUBROUTINE WRITE_DEN(FUNIT, U2)
			IMPLICIT NONE
			INTEGER, INTENT(IN) :: FUNIT
			REAL (8), DIMENSION(1:), INTENT(IN) :: U2
		END SUBROUTINE WRITE_DEN
	END INTERFACE
	
	INTERFACE
		SUBROUTINE CALCNU(CP, DT)
			USE, INTRINSIC :: ISO_C_BINDING
			COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(1:), INTENT(INOUT) :: CP
			REAL (8), INTENT(IN) :: DT
		END SUBROUTINE CALCNU
	END INTERFACE
	
	INTERFACE 
		SUBROUTINE NORMALIZE(CP)
			USE, INTRINSIC :: ISO_C_BINDING
			COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(1:), INTENT(INOUT) :: CP
		END SUBROUTINE NORMALIZE
	END INTERFACE
	!--------------INTERFACE BLOCKS----------------------
	INTEGER :: NI
	REAL (8) :: T, T1, T2
	INTEGER (8) :: CLICK_COUNTS_BEG, CLICK_COUNTS_END, CLICK_RATE
	REAL (8), DIMENSION(N) :: CP2
	REAL (8), DIMENSION(N) :: K, K2
	TYPE(C_PTR) :: PLAN1,PLAN2
	
	CALL SYSTEM_CLOCK(CLICK_COUNTS_BEG, CLICK_COUNTS_END)
	CALL CPU_TIME(T1)	
!
	CALL INITIALIZE(CP, K)
	CP2 = CP%RE*CP%RE + CP%IM*CP%IM
	OPEN(1, FILE='den-ini.txt')
	CALL WRITE_DEN(1,CP2)
	CLOSE(1)
	K2 = K * K
	T = 0D0

        PLAN1 = FFTW_PLAN_DFT_1D(N, CP, CPF, FFTW_FORWARD, FFTW_ESTIMATE)	! DFT
	PLAN2 = FFTW_PLAN_DFT_1D(N, CPF, CP, FFTW_BACKWARD, FFTW_ESTIMATE)	! INVERSE DFT
	OPEN(1,FILE='den-time.txt')
	DO NI=1,NRUN
		T = T + DT
		CALL CALCNU(CP, DT)							! SOLVING NON DERIVATIVE PART
!
		CALL FFTW_EXECUTE_DFT(PLAN1, CP, CPF)					! DFT
!
		CPF = EXP(-CI * DT * K2) * CPF		
!
		CALL FFTW_EXECUTE_DFT(PLAN2, CPF, CP)					! INVERSE DFT
		CP = CP / N
!
		! NORMALIZE(CP)	
		
		CP2 = CP%RE*CP%RE + CP%IM*CP%IM	
		IF (MOD(NI,50)==0) THEN
			WRITE(1, 8001) CP2
			WRITE(1,*)
		END IF		
	END DO
        CALL FFTW_DESTROY_PLAN(PLAN1)
	CALL FFTW_DESTROY_PLAN(PLAN2)	
	8001 FORMAT(F15.5, $)
	CLOSE(1)
	CP2 = CP%RE*CP%RE + CP%IM*CP%IM
	OPEN(1, FILE='den-fin.txt')
	CALL WRITE_DEN(1, CP2)
	CLOSE(1)
		
	CALL SYSTEM_CLOCK(CLICK_COUNTS_END, CLICK_RATE)
	CALL CPU_TIME(T2)
		
	OPEN(1, FILE='exectime.txt')
	WRITE(1,1000) INT(T2-T1)
	CLOSE(1)
	1000 FORMAT(I7, ' seconds')
	
END PROGRAM GP_SSF_1D

SUBROUTINE INITIALIZE(CP, K)
	USE, INTRINSIC :: ISO_C_BINDING
	USE GPE_DATA, ONLY : DX, X, X2
	USE COMM_DATA, ONLY : N, N2, LX, PI
	IMPLICIT NONE
	COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(1:), INTENT(INOUT) :: CP
	REAL (8), DIMENSION(1:), INTENT(INOUT) :: K
	INTEGER (8) :: I
!	
	X2 = X * X
	DO I=1,N
		X(I) = -LX / 2.0D0 + (I - 1) * DX
	END DO
	DO I=1,N2
		K(I) = (I - 1) * 2.0D0 * PI / LX
		K(I + N2) = - (N2 - I + 1) * 2.0D0 * PI / LX
	END DO
	CP = EXP(-X*X/5.0)
END SUBROUTINE INITIALIZE

SUBROUTINE CALCNU(CP, DT)
	USE, INTRINSIC :: ISO_C_BINDING
	USE COMM_DATA, ONLY : N
	USE GPE_DATA, ONLY : X2, G,  CI, G32, DG, PI 
	IMPLICIT NONE
	COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(1:), INTENT(INOUT) :: CP
	REAL (8), INTENT(IN) :: DT
	REAL (8), DIMENSION(N) :: P, P2, TMP1D, DP
!
	P = ABS(CP)
	P2 = P*P
	TMP1D = DT * (DG * P2 - G32 * (SQRT(2.0D0) / PI) * P)
	CP = CP * EXP(-CI * TMP1D)
END SUBROUTINE CALCNU

SUBROUTINE NORMALIZE(CP)
	USE, INTRINSIC :: ISO_C_BINDING
	USE GPE_DATA, ONLY : DX
	USE COMM_DATA, ONLY : N
	IMPLICIT NONE
	COMPLEX(C_DOUBLE_COMPLEX), DIMENSION(1:), INTENT(INOUT) :: CP
	!-----------------------
	INTERFACE 
		PURE FUNCTION SIMP(F,DX) RESULT (VALUE)
			REAL (8), DIMENSION(1:), INTENT(IN) :: F
			REAL (8), INTENT(IN) :: DX
			REAL (8) :: VALUE
		END FUNCTION SIMP
	END INTERFACE
	!-----------------------
	REAL (8), DIMENSION(N) :: P, P2
	REAL (8) :: ZNORM
	P = ABS(CP)
	P2 = P * P
	ZNORM = SQRT(SIMP(P2,DX))
	CP = CP/ZNORM
END SUBROUTINE NORMALIZE

PURE FUNCTION SIMP(F,DX) RESULT (VALUE)
	IMPLICIT NONE
	REAL (8), DIMENSION(:), INTENT(IN) :: F
	REAL (8), INTENT(IN) :: DX
	REAL (8) :: VALUE, F1, F2
	INTEGER :: I, N1
	
	N1 = SIZE(F) - 1
  	F1 = F(1) + F(N1-1) ! N EVEN 
 	F2 = F(2) 
  	DO I = 3, N1-3, 2
 	    F1 = F1 + F(I)
  	    F2 = F2 + F(I+1)
  	END DO
 	VALUE = DX*(F(1) + 4.D0*F1 + 2.D0*F2 + F(N1))/3.D0
END FUNCTION

SUBROUTINE WRITE_DEN(FUNIT, U2)
	USE COMM_DATA, ONLY : N
	USE GPE_DATA, ONLY  : X
	IMPLICIT NONE
	INTEGER, INTENT(IN) :: FUNIT
	REAL (8), DIMENSION(1:), INTENT(IN) :: U2
	INTEGER :: I
	
	DO I=1,N
		WRITE(FUNIT,8000) X(I), U2(I)
	END DO
	8000 FORMAT(2G17.8E3)	
END SUBROUTINE WRITE_DEN
