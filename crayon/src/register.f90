! $Id: register.f90 13577 2010-03-31 10:35:30Z AxelBrandenburg $
!
!  A module for setting up the f-array and related variables (`register' the
!  entropy, magnetic, etc modules).
!
module Register
!
  implicit none
!
  private
!
  public :: register_modules, initialize_modules, rprint_list
  public :: choose_pencils
!
  contains
!***********************************************************************
    subroutine register_modules()
!
!  Call all registration routines, i.e. initialise MPI and register
!  physics modules. Registration implies getting slices of the f-array
!  and setting logicals like lentropy to .true. This routine is called by
!  both, start.x and run.x .
!
!  6-nov-01/wolf: coded
!
      use Cdata
      use General,          only: setup_mm_nn
      use Io,               only: register_io
      use Mpicomm,          only: mpicomm_init,stop_it,stop_it_if_any
      use Param_Io,         only: get_datadir,get_snapdir
      use Sub
      use Density,          only: register_density
      use Entropy,          only: register_entropy
      use EquationOfState,  only: register_eos
      use Gravity,          only: register_gravity
      use Hydro,            only: register_hydro
      use InitialCondition, only: register_initial_condition
      use Magnetic,         only: register_magnetic
      use Shear,            only: register_shear
      use Shock,            only: register_shock
      use Viscosity,        only: register_viscosity
!
      logical :: ioerr
!
!  Initialize all mpi stuff.
!
      call mpicomm_init
!
!  Initialize index.pro file.
!
      if (lroot) then
        open(3,file=trim(datadir)//'/index.pro',status='replace')
        close(3)
      endif
!
!  Overwrite datadir from datadir.in, if that exists.
!
      call get_datadir(datadir)
      call get_snapdir(datadir_snap)
!
!  Set up the ordering of the pencils.
!
      call setup_mm_nn
!
!  Initialize nvar; is increased by the following routines.
!
      nvar     = 0
      naux     = 0
      naux_com = 0
!
!  Writing files for use with IDL.
!
      ioerr = .true.            ! will be overridden unless we go 911
      if (lroot) then
        print*, trim(datadir)//'/def_var.pro'
        open(15,FILE=trim(datadir)//'/def_var.pro',ERR=911)
        open(4,FILE=trim(datadir)//'/variables.pro',ERR=911)
        write(4,*) 'close,1'
        write(4,*) "openr,1, datadir+'/'+varfile, /F77"
        write(4,*) 'readu,1 $'
      endif
      ioerr = .false.
!
!  Initialize file for writing constants to be read by IDL.
!
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro')
        write (1,*) '; This file contain pc constants of interest to IDL'
        close (1)
      endif
!
!  Register variables in the f-array.
!
      call register_io
      call register_initial_condition
      call register_eos
      call register_shock
      call register_viscosity
      call register_hydro
      call register_gravity
      call register_density
      call register_entropy
      call register_magnetic
      call register_shear
!
!  Writing files for use with IDL.
!
      if (lroot) then
        do aux_count=1,maux
          write(4,'(a10)') aux_var(aux_count)
        enddo
        close(4)
        close(15)
      endif
!
      if (nvar /= mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_modules: nvar /= mvar. '// &
           'Check your MVAR and/or MAUX CONTRIBUTION in cparam.local')
      endif
!
!  Initialize headt for root processor only.
!
      if (lroot) headt=.true.
!
!  Something went wrong. Catches cases that would make mpich 1.x hang,
!  provided that this is the first attempt to write a file.
!
911   call stop_it_if_any(ioerr, &
          "Cannot open "//datadir//"/def_var.pro for writing" // &
          " -- is data/ visible from root node?")
!
    endsubroutine register_modules
!***********************************************************************
    subroutine initialize_modules(f,lstarting)
!
!  Call initialization routines, i.e. initialize physics and technical
!  modules. This implies some preparation of auxiliary quantities, often
!  based on input parameters. This routine is called by run.x (but not by
!  start.x) initially and each time the run parameters have been reread.
!
!  6-nov-01/wolf: coded
! 23-feb-03/axel: added physical constants conversion
!  7-oct-03/david: initialize_gravity before density, etc (its needed there)
! 11-sep-04/axel: began adding spherical coordinates
!
      use Cdata
      use Mpicomm, only: mpireduce_sum
      use Param_IO
      use Sub, only: remove_zprof
      use Density,          only: initialize_density
      use Deriv,            only: initialize_deriv
      use Entropy,          only: initialize_entropy
      use EquationOfState,  only: initialize_eos, units_eos
      use Gravity,          only: initialize_gravity
      use Hydro,            only: initialize_hydro
      use InitialCondition, only: initialize_initial_condition
      use Magnetic,         only: initialize_magnetic
      use Shear,            only: initialize_shear
      use Shock,            only: initialize_shock
      use Viscosity,        only: initialize_viscosity
!
      real, dimension(mx,my,mz,mfarray) :: f
      real, dimension (nz,nprocz) :: z_allprocs_tmp
      logical :: lstarting
      integer :: ivar
!
!  Defaults for some logicals; will later be set to true if needed
!
      lpenc_requested(:) = .false.
!
!  Evaluate physical units.
!  Used currently only in eos
!
      call units_general()
      call units_eos()
!
!  Calculated derived units.
!
      unit_mass=unit_density*unit_length**3
      unit_energy=unit_mass*unit_velocity**2
      unit_time=unit_length/unit_velocity
      unit_flux=unit_energy/(unit_length**2*unit_time)
!
!  Convert physical constants to code units.
!
      if (unit_system=='cgs') then
        if (lroot.and.ip<14) print*,'initialize_modules: ' &
          //'unit_velocity, unit_density, etc, are in cgs'
        hbar=hbar_cgs/(unit_energy*unit_time)
        k_B=k_B_cgs/(unit_energy/unit_temperature)
        mu0=mu0_cgs*unit_density*(unit_velocity/unit_magnetic)**2
        sigmaSB=sigmaSB_cgs/(unit_flux/unit_temperature**4)
        m_u=m_u_cgs/unit_mass
        m_p=m_p_cgs/unit_mass
        m_e=m_e_cgs/unit_mass
        eV=eV_cgs/unit_energy
        sigmaH_=sigmaH_cgs/unit_length**2
        kappa_es=kappa_es_cgs/(unit_length**2/unit_mass)
        c_light=c_light_cgs/unit_velocity
        G_Newton=G_Newton_cgs*unit_length**2*unit_density/unit_velocity**2
      elseif (unit_system=='SI') then
        if (lroot) print*,&
            'initialize_modules: unit_velocity, unit_density, etc, are in SI'
        hbar=hbar_cgs*1e-7/(unit_energy*unit_time)
        k_B=1e-7*k_B_cgs/(unit_energy/unit_temperature)
        mu0=1e-7*mu0_cgs*unit_density*(unit_velocity/unit_magnetic)**2
        m_u=m_u_cgs*1e-3/unit_mass
        m_p=m_p_cgs*1e-3/unit_mass
        m_e=m_e_cgs*1e-3/unit_mass
        eV=eV_cgs*1e-7/unit_energy
        sigmaH_=sigmaH_cgs*1e-4/unit_length**2
        sigmaSB=sigmaSB_cgs*1e-3/(unit_flux/unit_temperature**4)
        kappa_es=kappa_es_cgs*1e-1/(unit_length**2/unit_mass)
        c_light=c_light_cgs*1e-2/unit_velocity
        G_Newton=G_Newton_cgs*1e-3*unit_length**2*unit_density/unit_velocity**2
      endif
!
!  Calculate additional constants (now all in code units).
!
      m_H=m_p+m_e
      m_He=3.97153*m_H
      chiH=13.6*eV
      chiH_=0.754*eV
!
!  Run rest of initialization of individual modules.
!
      call initialize_deriv()
      call initialize_initial_condition(f)
      call initialize_eos()
      call initialize_gravity(f,lstarting)
      call initialize_density(f,lstarting)
      call initialize_hydro(f,lstarting)
      call initialize_entropy(f,lstarting)
      call initialize_magnetic(f,lstarting)
      call initialize_shear()
      call initialize_shock(f,lstarting)
      call initialize_viscosity(lstarting)
!
!  initialize time integrals
!  (leads to linker problem)
!
!---  call initialize_time_integrals(f)
!
! Store the value of impossible for use in IDL
!
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro',position="append")
        write (1,*) 'impossible=',impossible
        close (1)
      endif
!
!  print summary of variable names
!
      if (lroot) then
        open(3,file=trim(datadir)//'/varname.dat',status='replace')
        do ivar=1,nvar
          write(3,"(i4,2x,a)") ivar,varname(ivar)
        enddo
        close(3)
      endif
!
!----------------------------------------------------------------------------
!  Coordinate-related issues: nonuniform meshes, different corrdinate systems
!
!  Set z_allprocs, which contains the z values from all processors
!  ignore the ghost zones.
!
        z_allprocs(:,ipz+1)=z(n1:n2)
!
!  Communicate z_allprocs over all processors (if there are more than 1)
!  the final result is only present on the root processor.
!
      if (nprocz>1) then
        z_allprocs_tmp=z_allprocs
        call mpireduce_sum(z_allprocs_tmp,z_allprocs,(/nz,nprocz/))
      endif
!
!  Box volume and volume element.
!  x-extent
!
      box_volume=1.
      if (nxgrid/=1) then
        box_volume = box_volume*Lxyz(1)
        dVol1=xprim
      else
        dVol1=1.
      endif
!
!  y-extent
!
      if (nygrid/=1) then
        box_volume = box_volume*Lxyz(2)
        dVol2=yprim
      else
        dVol2=1.
      endif
!
!  z-extent
!
      if (nzgrid/=1) then
        box_volume = box_volume*Lxyz(3)
        dVol3=zprim
      else
        dVol3=1.
      endif
!
!  For a non-periodic mesh, multiply boundary points by 1/2.
!  Do it for each direction in turn.
!  If a direction has no extent, it is automatically periodic
!  and the corresponding step is therefore not called.
!
      if (.not.lperi(1)) then
        if (ipx==0) dVol1(1)=.5*dVol1(1)
        if (ipx==nprocx-1) dVol1(nx)=.5*dVol1(nx)
      endif
!
      if (.not.lperi(2)) then
        if (ipy==0.and.m==m1) dVol2=.5*dVol2
        if (ipy==nprocy-1.and.m==m2) dVol2=.5*dVol2
      endif
!
      if (.not.lperi(3)) then
        if (ipz==0.and.n==n1) dVol3=.5*dVol3
        if (ipz==nprocz-1.and.n==n2) dVol3=.5*dVol3
      endif
!
!  Print the value for which output is being produced.
!  (Have so far only bothered about single processor output.)
!
      if (lroot) then
        lpoint=min(max(l1,lpoint),l2)
        mpoint=min(max(m1,mpoint),m2)
        npoint=min(max(n1,npoint),n2)
        lpoint2=min(max(l1,lpoint2),l2)
        mpoint2=min(max(m1,mpoint2),m2)
        npoint2=min(max(n1,npoint2),n2)
        print*,'(x,y,z)(point)=',x(lpoint),y(mpoint),z(npoint)
        print*,'(x,y,z)(point2)=',x(lpoint2),y(mpoint2),z(npoint2)
      endif
!
!  Clean up profile files.
!
      call remove_zprof()
      lwrite_prof=.true.
!
!----------------------------------------------------------------------------
!  timestep: distinguish two cases,
!  (a) dt explicitly given in run.in -> ldt=.false.
!  (b) dt not given in run.in        -> ldt=.true.  -> calculate dt dynamically
!  Note that ldt will not change unless you RELOAD parameters.
!
! Why is this here?...
!   ajwm should this be moved to timestep.f90 as run_hooks_timestep() ??
!   AB   maybe not, because initialize_modules can also be run from start.f90,
!   AB   which has no knowledge of timestep.f90
!
      ldt = (dt==0.)            ! need to calculate dt dynamically?
      if (lroot .and. ip<14) then
        if (ldt) then
          print*,'timestep based on CFL cond; cdt=',cdt
        else
          print*, 'absolute timestep dt=', dt
        endif
      endif
!
    endsubroutine initialize_modules
!***********************************************************************
    subroutine units_general()
!
!  This routine calculates things related to units and must be called
!  before the rest of the units are being calculated.
!
!  12-jul-06/axel: adapted from units_eos
!
      use Cdata, only: unit_system,G_Newton,c_light,hbar,lroot, &
        unit_length,unit_velocity,unit_density,unit_magnetic
      use Cparam, only: G_Newton_cgs,c_light_cgs,hbar_cgs,impossible
      use Mpicomm, only: stop_it
!
!  Unless G_Newton,c_light,hbar are all set,
!  unit_velocity,unit_density,unit_length will be calculated
!
      if (G_Newton == impossible .or. &
           c_light == impossible .or. &
              hbar == impossible) then
        if (unit_velocity == impossible) unit_velocity=1.
        if (unit_density == impossible) unit_density=1.
        if (unit_length == impossible) unit_length=1.
      else
        if (unit_system == 'cgs') then
           unit_velocity=c_light_cgs/c_light
           unit_density=unit_velocity**5/((G_Newton_cgs/G_Newton)**2 &
                *(hbar_cgs/hbar))
           unit_length=sqrt((G_Newton_cgs/G_Newton) &
                *(hbar_cgs/hbar)/unit_velocity**3)
        elseif (unit_system == 'SI') then
           unit_velocity=c_light_cgs*1e-2/c_light
           unit_density=unit_velocity**5/((G_Newton_cgs*1e-3/G_Newton)**2 &
                *(hbar_cgs*1e-7/hbar))
           unit_length=sqrt((G_Newton_cgs*1e-3/G_Newton) &
                *(hbar_cgs*1e-7/hbar)/unit_velocity**3)
        endif
      endif
!
!  Set unit_magnetic=3.5449077018110318=sqrt(4*pi), unless it was set already.
!  Note that unit_magnetic determines the value of mu_0 in the rest of the code.
!
      if (unit_magnetic == impossible) unit_magnetic=3.5449077018110318
!
!  Check that everything is OK.
!
      if (lroot) print*,'units_general: unit_velocity=',unit_velocity
      if (lroot) print*,'units_general: unit_density=',unit_density
      if (lroot) print*,'units_general: unit_length=',unit_length
      if (lroot) print*,'units_general: unit_magnetic=',unit_magnetic
!
    endsubroutine units_general
!***********************************************************************
    subroutine choose_pencils()
!
!  Find out which pencils are needed for all time-steps and also for
!  diagnostics only. Also takes care of interdependent pencils.
!
!  20-nov-04/anders: coded
!
      use Cdata
!
      integer :: i
!
      if (lroot) print*, 'choose_pencils: finding out which pencils '// &
          'are needed for the pencil case'
!
!  Must set all pencil arrays to false in case of reload.
!
      lpenc_requested=.false.
      lpenc_diagnos=.false.
      lpenc_diagnos2d=.false.
!
!  Find out which pencils are needed for the pencil case.
!
      call pencil_criteria()
!
!  Set interdependent pencils.
!
      do i=1,3
        call pencil_interdep(lpenc_requested)
        call pencil_interdep(lpenc_diagnos)
        call pencil_interdep(lpenc_diagnos2d)
        call pencil_interdep(lpenc_video)
      enddo
!
!  Swap logical content of pencil number ipencil_swap (for testing).
!
      if (ipencil_swap/=0) then
        if (lpencil_requested_swap) then
          lpenc_requested(ipencil_swap) = (.not. lpenc_requested(ipencil_swap))
          print*, 'choose_pencils: Swapped requested pencil number ', &
              ipencil_swap, ' to ', lpenc_requested(ipencil_swap)
        endif
        if (lpencil_diagnos_swap) then
          lpenc_diagnos(ipencil_swap) = (.not. lpenc_diagnos(ipencil_swap))
          print*, 'choose_pencils: Swapped diagnostic pencil number ', &
              ipencil_swap, ' to ', lpenc_diagnos(ipencil_swap)
        endif
      endif
!
    endsubroutine choose_pencils
!***********************************************************************
    subroutine pencil_criteria()
!
!  Find out which pencils are needed for all the modules. In each call
!  the called module will inform about the pencils that it needs locally.
!  Interdependency among pencils is not solved here.
!
!  Note: No pencils can exist for the forcing module, because it is
!  used outside the pencil mn loop, so rho and 1/rho needs to be
!  calculated separately.
!
!  20-11-04/anders: coded
!
      use Cdata
      use EquationOfState, only: pencil_criteria_eos
      use Hydro,           only: pencil_criteria_hydro
      use Density,         only: pencil_criteria_density
      use Shock,           only: pencil_criteria_shock
      use Viscosity,       only: pencil_criteria_viscosity
      use Entropy,         only: pencil_criteria_entropy
      use Gravity,         only: pencil_criteria_gravity
      use Magnetic,        only: pencil_criteria_magnetic
      use Shear,           only: pencil_criteria_shear
!
      call pencil_criteria_density()
      call pencil_criteria_eos()
      call pencil_criteria_hydro()
      call pencil_criteria_shock()
      call pencil_criteria_viscosity()
      call pencil_criteria_entropy()
      call pencil_criteria_gravity()
      call pencil_criteria_magnetic()
      call pencil_criteria_shear()
!
    endsubroutine pencil_criteria
!***********************************************************************
    subroutine pencil_interdep(lpencil_in)
!
!  Find out about interdependent pencils. Each module knows what its own
!  pencils depend on. The dependency only needs to be specified one level
!  up, since this subroutine is called several times (currently three).
!
!  Note: No pencils can exist for the forcing module, because it is
!  used outside the pencil mn loop, so rho and 1/rho needs to be
!  calculated separately.
!
!  20-11-04/anders: coded
!
      use Cdata
      use EquationOfState, only: pencil_interdep_eos
      use Hydro, only: pencil_interdep_hydro
      use Density, only: pencil_interdep_density
      use Shock, only: pencil_interdep_shock
      use Viscosity, only: pencil_interdep_viscosity
      use Entropy, only: pencil_interdep_entropy
      use Gravity, only: pencil_interdep_gravity
      use Magnetic, only: pencil_interdep_magnetic
      use Shear, only: pencil_interdep_shear
      use Grid, only: pencil_interdep_grid
!
      logical, dimension (npencils) :: lpencil_in
!
      call pencil_interdep_grid(lpencil_in)
      call pencil_interdep_density(lpencil_in)
      call pencil_interdep_eos(lpencil_in)
      call pencil_interdep_hydro(lpencil_in)
      call pencil_interdep_shock(lpencil_in)
      call pencil_interdep_viscosity(lpencil_in)
      call pencil_interdep_entropy(lpencil_in)
      call pencil_interdep_gravity(lpencil_in)
      call pencil_interdep_magnetic(lpencil_in)
      call pencil_interdep_shear(lpencil_in)
!
    endsubroutine pencil_interdep
!***********************************************************************
    subroutine rprint_list(lreset)
!
!  Read variables to print and to calculate averages of from control files.
!
!   3-may-01/axel: coded
!
      use Cdata
      use Param_IO
      use Sub,             only: numeric_precision
      use Diagnostics
      use Hydro,           only: rprint_hydro
      use Density,         only: rprint_density
      use Entropy,         only: rprint_entropy
      use Magnetic,        only: rprint_magnetic
      use EquationOfState, only: rprint_eos
      use Gravity,         only: rprint_gravity
      use Shock,           only: rprint_shock
      use Viscosity,       only: rprint_viscosity
      use Shear,           only: rprint_shear
      use Mpicomm
!
      integer :: iname,inamev,inamez,inamey,inamex
      integer :: inamexy,inamexz
      integer :: iname_tmp,iread
      logical :: lreset,exist,print_in_double
      character (LEN=30)    :: cname_tmp
      character (LEN=fnlen) :: print_in_file
!
!  Read in the list of variables to be printed.
!  Recognize "!" and "#" as comments.
!
!  Read print.in.double if applicable, else print.in.
!
      print_in_file = 'print.in'
      inquire(FILE="print.in.double", EXIST=print_in_double)
      if (print_in_double .and. (numeric_precision() == 'D')) then
        print_in_file = 'print.in.double'
      endif
91    if (lroot) print*, 'Reading print formats from ' // trim(print_in_file)
      inquire(FILE=print_in_file, EXIST=exist)
      if (exist) then
        open(1,FILE=print_in_file)
        iname=0
        do iname_tmp=1,mname
          read(1,*,end=99) cname_tmp
          if (cname_tmp(1:1)/='!'.and.cname_tmp(1:1)/='#') then
            iname=iname+1
            cname(iname)=cname_tmp
          endif
        enddo
99      nname=iname
        if (lroot.and.ip<14) print*,'rprint_list: nname=',nname
        close(1)
      else
        open(1,FILE=print_in_file)
        write(1,*) "it(i9)"
        close(1)
        if (lroot) then
          print*, 'You must have a print.in file in the run directory!'
          print*, 'For now we generated a minimalistic version.'
          print*, 'Please edit it and type reload run.'
        endif
        goto 91
      endif
!
!  Read in the list of variables for video slices.
!
      inquire(file='video.in',exist=exist)
      if (exist .and. dvid/=0.0) then
        lwrite_slices=.true.
        open(1,file='video.in')
        inamev=0; iread=0
        do while (iread==0)
          inamev=inamev+1
          read(1,*,iostat=iread) cnamev(inamev)
        enddo
        nnamev=inamev
        close(1)
      endif
      if (lroot.and.ip<14) print*, 'rprint_list: ix,iy,iz,iz2=',ix,iy,iz,iz2
      if (lroot.and.ip<14) print*, 'rprint_list: nnamev=', nnamev
!
!  Read in the list of variables for xy-averages.
!
      inquire(file='xyaver.in',exist=exist)
      if (exist) then
!  Count the number of lines in it first.
        open(1,file='xyaver.in')
        nnamez=0; iread=0
        do while (iread==0)
          read(1,*,iostat=iread)
          if (iread==0) nnamez=nnamez+1
        enddo
        close(1)
        if (nnamez>0) then
!  Allocate the relevant arrays here...
          call allocate_xyaverages()
!  ... then read into these arrays.
          open(1,file='xyaver.in')
          do inamez=1,nnamez
            read(1,*,iostat=iread) cnamez(inamez)
          enddo
          close(1)
        endif
      endif
      if (lroot.and.ip<14) print*, 'rprint_list: nnamez=',nnamez
!
!  Read in the list of variables for xz-averages.
!
      inquire(file='xzaver.in',exist=exist)
      if (exist) then
!  Count the number of lines in it first.
        open(1,file='xzaver.in')
        nnamey=0; iread=0
        do while (iread==0)
          read(1,*,iostat=iread)
          if (iread==0) nnamey=nnamey+1
        enddo
        close(1)
        if (nnamey>0) then
!  Allocate the relevant arrays here...
          call allocate_xzaverages()
!  ... then read into these arrays.
          open(1,file='xzaver.in')
          do inamey=1,nnamey
            read(1,*,iostat=iread) cnamey(inamey)
          enddo
          close(1)
        endif
      endif
      if (lroot.and.ip<14) print*, 'rprint_list: nnamey=',nnamey
!
!  Read in the list of variables for yz-averages.
!
      inquire(file='yzaver.in',exist=exist)
      if (exist) then
!  Count the number of lines in it first.
        open(1,file='yzaver.in')
        nnamex=0; iread=0
        do while (iread==0)
          read(1,*,iostat=iread)
          if (iread==0) nnamex=nnamex+1
        enddo
        close(1)
        if (nnamex>0) then
!  Allocate the relevant arrays here...
          call allocate_yzaverages()
!  ... then read into these arrays.
          open(1,file='yzaver.in')
          do inamex=1,nnamex
            read(1,*,iostat=iread) cnamex(inamex)
          enddo
          close(1)
        endif
      endif
      if (lroot.and.ip<14) print*, 'rprint_list: nnamex=',nnamex
!
!  2-D averages: Read the files and allocate the relevant arrays here.
!
!  Read in the list of variables for y-averages.
!
      inquire(file='yaver.in',exist=exist)
      if (exist) then
!  Count the number of lines in it first.
        open(1,file='yaver.in')
        nnamexz=0; iread=0
        do while (iread==0)
          read(1,*,iostat=iread)
          if (iread==0) nnamexz=nnamexz+1
        enddo
        close(1)
        if (nnamexz>0) then
!  Allocate the relevant arrays here...
          call allocate_yaverages()
!  ... then read into these arrays.
          open(1,file='yaver.in')
          do inamexz=1,nnamexz
            read(1,*,iostat=iread) cnamexz(inamexz)
          enddo
          close(1)
        endif
      else
        lwrite_yaverages = .false. ! switch yaverages off
      endif
      if (lroot.and.ip<14) print*,'rprint_list: nnamexz=',nnamexz
!
!  Read in the list of variables for z-averages.
!
      inquire(file='zaver.in',exist=exist)
      if (exist) then
!  Count the number of lines in it first.
        open(1,file='zaver.in')
        nnamexy=0; iread=0
        do while (iread==0)
          read(1,*,iostat=iread )
          if (iread==0) nnamexy=nnamexy+1
        enddo
        close(1)
        if (nnamexy>0) then
!  Allocate the relevant arrays here...
          call allocate_zaverages()
!  ... then read into these arrays.
          open(1,file='zaver.in')
          do inamexy=1,nnamexy
            read(1,*,iostat=iread) cnamexy(inamexy)
          enddo
          close(1)
        endif
      else
        lwrite_zaverages = .false. ! switch zaverages off
      endif
      if (lroot.and.ip<14) print*,'rprint_list: nnamexy=',nnamexy
!
!  Set logical for 2-D averages.
!
      lwrite_2daverages= &
          lwrite_yaverages.or.lwrite_zaverages
!
!  Check which variables are set.
!  For the convenience of idl users, the indices of variables in
!  the f-array and the time_series.dat files are written to data/index.pro.
!
      if (lroot) open(3,file=trim(datadir)//'/index.pro',position='append')
      call rprint_general         (lreset,LWRITE=lroot)
      call rprint_hydro           (lreset,LWRITE=lroot)
      call rprint_density         (lreset,LWRITE=lroot)
      call rprint_entropy         (lreset,LWRITE=lroot)
      call rprint_magnetic        (lreset,LWRITE=lroot)
      call rprint_eos             (lreset,LWRITE=lroot)
      call rprint_gravity         (lreset,LWRITE=lroot)
      call rprint_shock           (lreset,LWRITE=lroot)
      call rprint_viscosity       (lreset,LWRITE=lroot)
      call rprint_shear           (lreset,LWRITE=lroot)
      if (lroot) close(3)
!
    endsubroutine rprint_list
!***********************************************************************
    subroutine rprint_general(lreset,lwrite)
!
!  Reads and registers *general* print parameters.
!
!   8-jun-02/axel: adapted from hydro
!
      use Cdata
      use Diagnostics
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  Reset everything in case of RELOAD.
!  (general variables that are defined in Cdata)
!
      if (lreset) then
        idiag_t=0; idiag_it=0; idiag_dt=0; idiag_walltime=0
        idiag_timeperstep=0
        idiag_rcylmphi=0; idiag_phimphi=0; idiag_zmphi=0; idiag_rmphi=0
        idiag_dtv=0; idiag_dtdiffus=0; idiag_Rmesh=0; idiag_Rmesh3=0
        idiag_maxadvec=0
      endif
!
!  iname runs through all possible names that may be listed in print.in.
!
      if (lroot.and.ip<14) print*,'rprint_register: run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'t',idiag_t)
        call parse_name(iname,cname(iname),cform(iname),'it',idiag_it)
        call parse_name(iname,cname(iname),cform(iname),'dt',idiag_dt)
        call parse_name(iname,cname(iname),cform(iname),'dtv',idiag_dtv)
        call parse_name(iname,cname(iname),cform(iname),'dtdiffus',idiag_dtdiffus)
        call parse_name(iname,cname(iname),cform(iname),'Rmesh',idiag_Rmesh)
        call parse_name(iname,cname(iname),cform(iname),'Rmesh3',idiag_Rmesh3)
        call parse_name(iname,cname(iname),cform(iname),'maxadvec',idiag_maxadvec)
        call parse_name(iname,cname(iname),cform(iname),&
            'walltime',idiag_walltime)
        call parse_name(iname,cname(iname),cform(iname),&
            'timeperstep',idiag_timeperstep)
      enddo
!
!  Write column where which variable is stored.
!
      if (lwr) then
        write(3,*) 'i_t=',idiag_t
        write(3,*) 'i_it=',idiag_it
        write(3,*) 'i_dt=',idiag_dt
        write(3,*) 'i_walltime=',idiag_walltime
        write(3,*) 'i_timeperstep=',idiag_timeperstep
        write(3,*) 'i_rcylmphi=',idiag_rcylmphi
        write(3,*) 'i_phimphi=',idiag_phimphi
        write(3,*) 'i_zmphi=',idiag_zmphi
        write(3,*) 'i_rmphi=',idiag_rmphi
        write(3,*) 'i_dtv=',idiag_dtv
        write(3,*) 'i_dtdiffus=',idiag_dtdiffus
        write(3,*) 'i_Rmesh=',idiag_Rmesh
        write(3,*) 'i_Rmesh3=',idiag_Rmesh3
        write(3,*) 'i_maxadvec=',idiag_maxadvec
        write(3,*) 'nname=',nname
      endif
!
    endsubroutine rprint_general
!***********************************************************************
endmodule Register
