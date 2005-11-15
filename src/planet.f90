! $Id: planet.f90,v 1.6 2005-11-15 10:20:35 wlyra Exp $
!
!  This modules contains the routines for accretion disk and planet
!  building simulations. 
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lplanet = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************
!
! This module takes care of (mostly) everything related to the 
! planet module
!
module Planet
  
  use Cdata
  use Cparam
  use Messages
  
  implicit none
  
  include 'planet.h' 
  
  !initialize variables needed for the planet module

  integer :: dummy1
  namelist /planet_init_pars/ dummy1
    
 !
  ! run parameters
  !
  
  !things needed for companion
  real :: Rx=0.,Ry=0.,Rz=0.,gc=0.  !location and mass
  real :: b=0.      !peak radius for potential
  integer :: nc=2   !exponent of smoothed potential 
  logical :: lramp=.false.
  logical :: lwavedamp=.false.,llocal_iso=.false.

  namelist /planet_run_pars/ Rx,Ry,Rz,gc,nc,b,lramp, &
       lwavedamp,llocal_iso
! 

  integer :: idiag_torqint=0,idiag_torqext=0
  integer :: idiag_torqrocheint=0,idiag_torqrocheext=0
  integer :: idiag_totalenergy=0,idiag_angularmomentum

  contains

!***********************************************************************
    subroutine register_planet()
!
!  06-nov-05/wlad: coded
!
      use Cdata, only: ip,nvar,lroot !,mvar,nvar
      use Mpicomm, only: stop_it
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_planet called twice')
      first = .false.
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_planet: ENTER'
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: planet.f90,v 1.6 2005-11-15 10:20:35 wlyra Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_planet: nvar > mvar')
      endif
!
    endsubroutine register_planet
!***********************************************************************
    subroutine initialize_planet(f,lstarting)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  08-nov-05/wlad: coded
!
!will need to add itorque as f-variable
      real, dimension (mx,my,mz,mvar+maux) :: f
      logical :: lstarting

      if (lroot) print*, 'initialize_planet'

!
    endsubroutine initialize_planet
!***********************************************************************
    subroutine pencil_criteria_planet()
! 
!  All pencils that the Planet module depends on are specified here.
! 
!  06-nov-05/wlad: coded
!
      use Cdata
!
      
      lpenc_requested(i_lnrho)=.true.
      
!
    endsubroutine pencil_criteria_planet
!***********************************************************************
    subroutine read_planet_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat).and.NO_WARN) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_planet_init_pars
!***********************************************************************
    subroutine write_planet_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine write_planet_init_pars
!***********************************************************************
    subroutine read_planet_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=planet_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=planet_run_pars,ERR=99)
      endif
                                                                                                                                                                                                
99    return
    endsubroutine read_planet_run_pars
!***********************************************************************
    subroutine write_planet_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=planet_run_pars)

    endsubroutine write_planet_run_pars
!***********************************************************************
    subroutine rprint_planet(lreset,lwrite)
!
!  reads and registers monitoring quantities for planet-disk
!
!  06-nov-05/wlad: coded
!
      use Cdata
      use Sub
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
         idiag_torqint=0
         idiag_torqext=0
         idiag_torqrocheint=0
         idiag_torqrocheext=0
         idiag_totalenergy=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      if(lroot.and.ip<14) print*,'rprint_gravity: run through parse list'
      do iname=1,nname
         call parse_name(iname,cname(iname),cform(iname),&
              'torqint',idiag_torqint)
         call parse_name(iname,cname(iname),cform(iname),&
              'torqext',idiag_torqext)
         call parse_name(iname,cname(iname),cform(iname),&
              'torqrocheint',idiag_torqrocheint)
         call parse_name(iname,cname(iname),cform(iname),&
              'torqrocheext',idiag_torqrocheext)
         call parse_name(iname,cname(iname),cform(iname),&
              'totalenergy',idiag_totalenergy)
         call parse_name(iname,cname(iname),cform(iname),&
              'angularmomentum',idiag_angularmomentum)
      enddo
!
!  write column, idiag_XYZ, where our variable XYZ is stored
!  idl needs this even if everything is zero
!
      if (lwr) then
        write(3,*) 'i_torqint=',idiag_torqint
        write(3,*) 'i_torqext=',idiag_torqext
        write(3,*) 'i_torqrocheint=',idiag_torqrocheint
        write(3,*) 'i_torqrocheext=',idiag_torqrocheext
        write(3,*) 'i_totalenergy=',idiag_totalenergy
        write(3,*) 'i_angularmomentum=',idiag_angularmomentum
        write(3,*) 'nname=',nname
      endif
!
      if (NO_WARN) print*,lreset  !(to keep compiler quiet)
!
    endsubroutine rprint_planet
!***********************************************************************
    subroutine gravity_companion(f,df,p,gs)
!
!  add duu/dt according to the gravity of a companion offcentered by (Rx,Ry,Rz)
!
!  12-aug-05/wlad: coded
!  08-nov-05/wlad: moved here (previously in Gravity Module)
!

      use Cdata
      use Sub
      use Global
!     
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real, dimension (nx,3) :: ggc,ggs
      real, dimension (nx) :: g_companion,rrc,rrs,g_star,dens
      real :: Omega_inertial,Rc,phase,phi,ax,ay,az,gtc
      real :: Rs, axs,ays,azs,mc,ms,phis,gs

      gtc = gc
      if (lramp) then
         !ramp up the mass of the planet for 5 periods
         !ramping is for the comparison project
         if (t .le. 10*pi) then
            if (headtt) print*,&
                 'gravity_companion: Ramping up the mass of the companion'
            gtc = gc* (sin(t/20))**2  !20 = pi/10*Period=2pi
         endif
      endif

      if (headtt) print*,&
           'gravity_companion: Adding gravity of companion located at x,y,z=',Rx,Ry,Rz
      if (headtt) print*,&
           'gravity_companion: Mass ratio of secondary-to-primary = ',gc/gs

      if (Omega /= 0) then  
         if (headtt) print*,'gravity_companion: corotational frame'
         ax = Rx  
         ay = Ry            
      else
         if (headtt) print*,'gravity_companion: inertial frame'
         !add these three to grav_run_pars later
         Rc = sqrt(Rx**2+Ry**2+Rz**2)
         Omega_inertial = sqrt(gs/Rc**3)
         phase = acos(Rx/Rc)

         phi = Omega_inertial*t + phase  
         ax = Rc * cos(phi) 
         ay = Rc * sin(phi) 
      endif
            
      az = Rz !just for notational consistency

      rrc=sqrt((x(l1:l2)-ax)**2+(y(m)-ay)**2+(z(n)-az)**2)
            
      g_companion=-gtc*rrc**(nc-1) &
          *(rrc**nc+b**nc)**(-1./nc-1.)

         ggc(:,1) = (x(l1:l2)-ax)/(rrc)*g_companion 
         ggc(:,2) = (y(  m  )-ay)/(rrc)*g_companion
         ggc(:,3) = (z(  n  )-az)/(rrc)*g_companion
      ! 

      df(l1:l2,m,n,iux:iuz) = df(l1:l2,m,n,iux:iuz) + ggc
      
      if (lwavedamp) call wave_damping(f,df)

      !gravity star

      phis = phi + pi
      mc = gtc ; ms = 1 - gc ; Rs = Rc*(gc/ms) 
      
      axs = Rs * cos(phis) 
      ays = Rs * sin(phis) 
      azs = 0. !notational consistency

      rrs=sqrt((x(l1:l2)-axs)**2+(y(m)-ays)**2+(z(n)-azs)**2)
      
      !gravity from star
      call gravity_star(gs,g_star,axs,ays)

      rrs=sqrt((x(l1:l2)-axs)**2+(y(m)-ays)**2+(z(n)-azs)**2)

      ggs(:,1) = (x(l1:l2)-axs)/(rrs)*g_star
      ggs(:,2) = (y(  m  )-ays)/(rrs)*g_star
      ggs(:,3) = (z(  n  )-azs)/(rrs)*g_star
      
      !reset the gravity from the star as global variable 
      
      call set_global(ggs,m,n,'gg',nx)
      
      !stuff for calc_torque

      if ((idiag_torqint/=0) .or. (idiag_torqext/=0) .or. &
           (idiag_torqrocheint/=0) .or.(idiag_torqrocheext/=0)) then 
         dens = f(l1:l2,m,n,ilnrho)
         call calc_torque(dens,gtc,ax,ay,b,Rc,phi)
      endif

      
     !move to gravity companion later
      if ((idiag_totalenergy/=0).or.(idiag_angularmomentum/=0)) &
           call calc_monitored(f,axs,ays,ax,ay,gs)
      

    endsubroutine gravity_companion
!***********************************************************************
    subroutine calc_torque(dens,gtc,ax,ay,b,Rc,phi)

! 05-nov-05/wlad : coded

      use Sub
      use Cdata

      real, dimension(nx) :: r,torqint,torqext
      real, dimension(nx) :: torqrocheint,torqrocheext
      real, dimension(nx) :: dist,rpre,dens
      real :: b,ax,ay,Rc,phi,roche,gtc
      integer :: i

      r = sqrt(x(l1:l2)**2 + y(m)**2)

      dist = sqrt((x(l1:l2)-ax)**2 + (y(m)-ay)**2)
      rpre = ax*y(m) - ay*x(l1:l2)

      torqint = 0.   ; torqext=0.
      torqrocheint=0.; torqrocheext=0.


      roche = Rc*(gtc/3.)**(1./3.) !Jupiter roche

      do i=1,nx
         !external torque, excluding roche lobe
         if ((r(i).ge.Rc).and.(r(i).le.r_ext).and.(dist(i).ge.roche)) then 
            torqext(i) = gtc*dens(i)*rpre(i)*(dist(i)**2+b**2)**(-1.5)*dx*dy
         endif 
      
         !internal torque, excluding roche lobe
         if ((r(i).le.Rc).and.(r(i).ge.r_int).and.(dist(i).ge.roche)) then
            torqint(i) = gtc*dens(i)*rpre(i)*(dist(i)**2+b**2)**(-1.5)*dx*dy
         endif

         !external torque, roche lobe
         if ((r(i).ge.Rc).and.(dist(i).ge.0.5*roche).and.(dist(i).le.roche)) then 
            torqrocheext(i) = gtc*dens(i)*rpre(i)*(dist(i)**2+b**2)**(-1.5)*dx*dy
         endif 
      
         !internal torque, roche lobe
         if ((r(i).le.Rc).and.(dist(i).ge.0.5*roche).and.(dist(i).le.roche)) then 
            torqrocheint(i) = gtc*dens(i)*rpre(i)*(dist(i)**2+b**2)**(-1.5)*dx*dy
         endif


      enddo

      !call sum_mn_name(torque,idiag_torqint)

      call sum_mn_name(torqint,idiag_torqint)
      call sum_mn_name(torqext,idiag_torqext)
      call sum_mn_name(torqrocheint,idiag_torqrocheint)
      call sum_mn_name(torqrocheext,idiag_torqrocheext)

    endsubroutine calc_torque
!***********************************************************************
    subroutine local_isothermal(cs20,cs2)
!
!22-aug-05/wlad: coded
!08-nov-05/wlad: moved here (previously in the EoS module)
!
!
! Locally isothermal structure for accretion disks. 
! The energy equation is not solved,but the variation
! of temperature with radius (T ~ r-1) is crucial for the
! treatment of ad hoc alpha viscosity.
!
! cs = H * Omega, being H the scale height and (H/r) = cte.
!
      use Cdata
      use Global, only: get_global

      real, intent(in)  :: cs20
      real, dimension (nx), intent(out) :: cs2
      real, dimension (nx) :: r
      integer :: i
!
!     It is better to set cs2 as a global variable than to recalculate it
!     at every timestep...
!
      if (headtt) print*,&
           'planet: local isothermal equation of state for accretion disk'
      
      !call get_global(cs2,m,n,'cs2')

      r = sqrt(x(l1:l2)**2 + y(m)**2)

      where ((r.le.0.4).and.(r.ge.0.2)) 
         cs2 =  0.00696037     &
              + 0.00285893*r   &
              - 0.0471130 *r**2 &
              + 0.234658  *r**3 &
              + 0.0636717 *r**4 &
              - 3.01896   *r**5 &
              + 6.47995   *r**6 &
              - 4.07479   *r**7
      endwhere
      where (r.gt.0.4) 
         cs2 = (0.05*r**(-0.5))**2 
      endwhere
      where (r.lt.0.2) 
         cs2 = 0.007
      endwhere
      
    endsubroutine local_isothermal
!***********************************************************
    subroutine wave_damping(f,df)
!
! 05-nov-05/wlad : coded
!
! Wave killing zone. Its only purpose is to have the same 
! specifications as Miguel's setup for the comparison project.
!
! As far as I understand, this thing is just like udamping 
! but with a varying pdamp, in the form of
! a parabola y=a*x**2 + c. Performs like freezing in the sense
! that it does not change the derivative in the boundary of the
! physical zone, but it does not stop the material completely
! in the outer boundary of the freezing ring.
!

      use Cdata
      use Global

      real, dimension(mx,my,mz,mvar+maux) :: f
      real, dimension(mx,my,mz,mvar) :: df
      integer ider,j,k,i,ii
      real, dimension(nx,3) :: gg_mn
      real, dimension(nx) :: r,pdamp,aux0,velx0,vely0
      real :: tau

      if (headtt) print*,&
           'wave_damping: damping motions for inner and outer boundary'

      
      tau = 2*pi/(0.4)**(-1.5)
      r = sqrt(x(l1:l2)**2 + y(m)**2)
     
      !for 0.4 : 1 ; 0.5 : 0
      pdamp = -11.111111*r**2 + 2.77777778  !parabolic function R
      !for 0.4 : 0 ; 0.5 : 1
      !pdamp = 11.1111111*r**2 - 1.777777778  
      
      where (r .le. 0.4) 
         pdamp = 1.
      endwhere
      where (r .ge. 0.5)
         pdamp = 0.
      endwhere
      
      call get_global(gg_mn,m,n,'gg')
      aux0 = 1./r*sqrt(gg_mn(:,1)**2+gg_mn(:,2)**2+gg_mn(:,3)**2)
      !aux0 is omega2
           
      !aux0 = g0*r**(n_pot-2)*(r**n_pot+r0_pot**n_pot)**(-1./n_pot-1.) 
      !aux is gravity, aux0 is omega**2
      
      velx0 =  -y(  m  ) * sqrt(aux0)   !initial conditions
      vely0 =  x(l1:l2) * sqrt(aux0)
      
      do i=l1,l2
         ii = i-l1+1
         if ((r(ii).le.0.5).and.(r(ii).gt.0.4)) then
            df(i,m,n,ilnrho) = df(i,m,n,ilnrho) - (f(i,m,n,ilnrho) - 1.       )/tau * pdamp(ii) 
            df(i,m,n,iux)    = df(i,m,n,iux)    - (f(i,m,n,iux)    - velx0(ii))/tau * pdamp(ii)
            df(i,m,n,iuy)    = df(i,m,n,iuy)    - (f(i,m,n,iuy)    - vely0(ii))/tau * pdamp(ii)
         endif
      enddo
      
     
     !outer boundary
     
     tau = 2*pi/(r_ext)**(-1.5)
     
     !!for 2.1 : 0 , 2.5 : 1
     pdamp = 0.543478*r**2 - 2.3967391  !parabolic function R
     !!for 2.1 : 1, 2.5 : 0
     !pdamp = -0.543478*r**2 + 3.3967375
     
     
     where (r .ge. 2.5) 
        pdamp = 1.
     endwhere
     where (r .le. 2.1)
        pdamp = 0.
     endwhere
     
     do i=l1,l2
        ii = i-l1+1
        if ((r(ii) .ge. 2.1).and.(r(ii).le.2.5)) then
           df(i,m,n,ilnrho) = df(i,m,n,ilnrho) - (f(i,m,n,ilnrho) - 1.       )/tau * pdamp(ii) 
           df(i,m,n,iux)    = df(i,m,n,iux)    - (f(i,m,n,iux)    - velx0(ii))/tau * pdamp(ii)
           df(i,m,n,iuy)    = df(i,m,n,iuy)    - (f(i,m,n,iuy)    - vely0(ii))/tau * pdamp(ii)
        endif
     enddo

   endsubroutine wave_damping
!***************************************************************
   subroutine gravity_star(gs,g_r,xstar,ystar)

     use Cdata

     real, dimension (nx), intent(out) :: g_r
     real, dimension (nx) :: rr_mn
     real, optional :: xstar,ystar !initial position of star
     integer :: i
     real :: gs,axs,ays

     if (present(xstar)) then;axs=xstar;else;axs=0.;endif
     if (present(ystar)) then;ays=ystar;else;ays=0.;endif
  
     rr_mn = sqrt((x(l1:l2)-axs)**2 + (y(m)-ays)**2)

     !smooth the potential locally (only for r < r0)
     !
     !needed when the gravity profile 
     !should be like rr_mn in the inner boundary
     !but one does not want the ridiculous
     !smoothing that smooth_newton gives to n=2 
     
     
      
     where ((rr_mn.le.0.4).and.(rr_mn.ge.0.2)) 

        !g_r(i) = -1./(8*r0_pot) &
        !     *(20.*rr_mn(i)/r0_pot**2 - 12*rr_mn(i)**3/r0_pot**4)
           
        g_r = 0.0733452     &
             - 33.0137*rr_mn   &
             + 136.921*rr_mn**2 &
             - 1061.37*rr_mn**3 &
             + 2801.66*rr_mn**4 &
             + 606.876*rr_mn**5 &
             - 9074.97*rr_mn**6 &
             + 7504.01*rr_mn**7
     endwhere
     where (rr_mn.gt.0.4)  
        g_r = -gs/rr_mn**2
     endwhere
     where (rr_mn.lt.0.2) 
        !a=-13.3333333333
        !g_r(i) = -1./(8*r0_pot) &
        !     *20.*rr_mn(i)/r0_pot**2
        g_r = 2*rr_mn*(-13.3333333333)
     endwhere
      
   endsubroutine gravity_star
!***************************************************************
   subroutine calc_monitored(f,xs,ys,xp,yp,gs)

! calculate total energy and output its evolution 
! as monitored variable
!
! 10-nov-05/wlad : coded


     use Sub
     use Cdata
 
     real, dimension(mx,my,mz,mvar+maux) :: f
     real, dimension(nx) :: rstar,rplanet,vel,r,uphi
     real, dimension(nx) :: angular_momentum
     real, dimension(nx) :: kin_energy,pot_energy,total_energy
     real :: xs,ys,xp,yp,gs !position of star and planet

     if (headtt) print*,'planet : calculate total energy'
     if (headtt) print*,'planet : calculate total angular momentum'

     !calculate the total energy and integrate it

     rstar   = sqrt((x(l1:l2)-xs)**2 + (y(m)-ys)**2)+epsi
     rplanet = sqrt((x(l1:l2)-xp)**2 + (y(m)-yp)**2)+epsi

     !kinetic energy
     vel = sqrt(f(l1:l2,m,n,iux)**2 + f(l1:l2,m,n,iuy)**2)
     kin_energy = f(l1:l2,m,n,ilnrho) * vel**2/2.
     
     !potential energy

     pot_energy = -(gs/rstar + gc/rplanet)*f(l1:l2,m,n,ilnrho)

     total_energy = kin_energy + pot_energy

     call sum_lim_mn_name(total_energy,idiag_totalenergy)

     r = sqrt(x(l1:l2)**2 + y(m)**2)+epsi !this is correct: baricenter
     uphi = (-f(l1:l2,m,n,iux)*y(m) + f(l1:l2,m,n,iuy)*x(l1:l2))/r

     angular_momentum = f(l1:l2,m,n,ilnrho) * r * uphi
          
     call sum_lim_mn_name(angular_momentum,idiag_angularmomentum)

   endsubroutine calc_monitored
!***************************************************************
  endmodule Planet
  
