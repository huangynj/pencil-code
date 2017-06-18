! $Id$
!
! This module handles the mass of super-particles.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MPVAR CONTRIBUTION 1
!
! CPARAM logical, parameter :: lparticles_mass = .true.
!
!***************************************************************
module Particles_mass
!
  use Cdata
  use Cparam
  use General, only: keep_compiler_quiet
  use Messages
  use Particles_cdata
!
  implicit none
!
  include 'particles_mass.h'
!
  contains
!***********************************************************************
    subroutine register_particles_mass()
!
! Set up indices for access to the fp and dfp arrays.
!
! 18-jun-17/ccyang: coded
!
      if (lroot) call svn_id("$Id$")
!
! Index for particle mass.
!
      imp = npvar + 1
      npvar = npvar + 1
      pvarname(imp) = 'imp'
!
! Check that the fp and dfp arrays are big enough.
!
      chknpvar: if (npvar > mpvar) then
        if (lroot) print *, 'npvar = ', npvar, ', mpvar = ', mpvar
        call fatal_error('register_particles_mass', 'npvar > mpvar')
      endif chknpvar
!
    endsubroutine register_particles_mass
!***********************************************************************
    subroutine initialize_particles_mass(f)
!
! Perform any post-parameter-read initialization i.e. calculate derived
! parameters.
!
! 18-jun-17/ccyang: dummy
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine initialize_particles_mass
!***********************************************************************
    subroutine init_particles_mass(f, fp)
!
! Initialize particle mass.
!
! 18-jun-17/ccyang: coded
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mpar_loc,mparray), intent(inout) :: fp
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(fp)
!
! Assign mp_swarm to all particles.
!
      fp(1:npar_loc,imp) = mp_swarm
!
    endsubroutine init_particles_mass
!***********************************************************************
    subroutine pencil_criteria_par_mass()
!
! All pencils that the Particles_mass module depends on are specified
! here.
!
! 18-jun-17/ccyang: dummy
!
    endsubroutine pencil_criteria_par_mass
!***********************************************************************
    subroutine dpmass_dt(f, df, fp, dfp, ineargrid)
!
! Evolution of particle mass.
!
! 18-jun-17/ccyang: dummy
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mx,my,mz,mvar), intent(in) :: df
      real, dimension(mpar_loc,mparray), intent(in) :: fp
      real, dimension(mpar_loc,mpvar), intent(in) :: dfp
      integer, dimension(mpar_loc,3), intent(in) :: ineargrid
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(fp)
      call keep_compiler_quiet(dfp)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine dpmass_dt
!***********************************************************************
    subroutine dpmass_dt_pencil(f, df, fp, dfp, p, ineargrid)
!
! Evolution of particle mass in pencils.
!
! 18-jun-17/ccyang: dummy
!
      real, dimension(mx,my,mz,mfarray), intent(in) :: f
      real, dimension(mx,my,mz,mvar), intent(in) :: df
      real, dimension(mpar_loc,mparray), intent(in) :: fp
      real, dimension(mpar_loc,mpvar), intent(in) :: dfp
      type(pencil_case), intent(in) :: p
      integer, dimension(mpar_loc,3), intent(in) :: ineargrid
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
      call keep_compiler_quiet(ineargrid)
!
    endsubroutine dpmass_dt_pencil
!***********************************************************************
    subroutine read_particles_mass_init_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_mass_init_pars
!***********************************************************************
    subroutine write_particles_mass_init_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_mass_init_pars
!***********************************************************************
    subroutine read_particles_mass_run_pars(iostat)
!
      integer, intent(out) :: iostat
!
      iostat = 0
!
    endsubroutine read_particles_mass_run_pars
!***********************************************************************
    subroutine write_particles_mass_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_particles_mass_run_pars
!***********************************************************************
    subroutine rprint_particles_mass(lreset, lwrite)
!
! Read and register print parameters relevant for particle mass.
!
! 18-jun-17/ccyang: coded
!
      logical, intent(in) :: lreset
      logical, intent(in), optional :: lwrite
!
      logical :: lwr
!
! Write information to index.pro.
!
      lwr = .false.
      if (present(lwrite)) lwr = lwrite
      if (lwr) write(3,*) 'imp = ', imp
!
      call keep_compiler_quiet(lreset)
!
    endsubroutine rprint_particles_mass
!***********************************************************************
endmodule Particles_mass
