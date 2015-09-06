; +
; NAME:
;       PC_READ_VAR_TIME
;
; PURPOSE:
;       Read time of a given var.dat, or other VAR file.
;
;       Returns the time from a snapshot (var) file generated by Pencil Code.
;
; CATEGORY:
;       Pencil Code, File I/O
;
; CALLING SEQUENCE:
;       pc_read_var_time, time=time, varfile=varfile, datadir=datadir, /quiet
; KEYWORD PARAMETERS:
;    datadir: Specifies the root data directory. Default: './data'.  [string]
;    varfile: Name of the var file. Default: 'var.dat'.              [string]
;   allprocs: Load data from the allprocs directory.                 [integer]
;   /reduced: Load reduced collective varfiles.
;
;       time: Variable in which to return the loaded time.           [real]
;exit_status: Suppress fatal errors in favour of reporting the
;             error through exit_status/=0.
;
;     /quiet: Suppress any information messages and summary statistics.
;      /help: Display this usage information, and exit.
;
; EXAMPLES:
;       pc_read_var, time=t              ;; read time into variable t
;
; MODIFICATION HISTORY:
;       $Id$
;       Written by: Antony J Mee (A.J.Mee@ncl.ac.uk), 27th November 2002
;
;-
pro pc_read_var_time,                                                              $
    time=time, varfile=varfile_, allprocs=allprocs, datadir=datadir, param=param,  $
    procdim=dim, ivar=ivar, swap_endian=swap_endian, f77=f77, reduced=reduced,     $
    exit_status=exit_status, quiet=quiet

COMPILE_OPT IDL2,HIDDEN
;
; Use common block belonging to derivative routines etc. so we can
; set them up properly.
;
  common pc_precision, zero, one
  common cdat_coords,coord_system
;
; Default settings.
;
  default, reduced, 0
  default, quiet, 0
;
  if (arg_present(exit_status)) then exit_status=0
;
; Name and path of varfile to read.
;
  if (n_elements(ivar) eq 1) then begin
    default, varfile_, 'VAR'
    varfile = varfile_ + strcompress(string(ivar),/remove_all)
  endif else begin
    default, varfile_, 'var.dat'
    varfile = varfile_
  endelse
;
; find varfile and set configuration parameters accordingly
;
  pc_find_config, varfile, datadir=datadir, procdir=procdir, dim=dim, allprocs=allprocs, reduced=reduced, swap_endian=swap_endian, f77=f77, mvar_io=mvar_io, start_param=param
;
; Local shorthand for some parameters.
;
  precision = dim.precision
  if (precision eq 'D') then bytes = 8 else bytes = 4
;
; Initialize / set default returns for ALL variables.
;
  t=zero
  x=fltarr(dim.mx)*one
  y=fltarr(dim.my)*one
  z=fltarr(dim.mz)*one
  dx=zero
  dy=zero
  dz=zero
  deltay=zero
;
; Get a free unit number.
;
  get_lun, file
;
; Build the full path and filename.
;
  filename = procdir + varfile
;
; Check for existence and read the data.
;
  if (not file_test(filename)) then begin
    if (arg_present(exit_status)) then begin
      exit_status=1
      print, 'ERROR: cannot find file '+ filename
      close, /all
      return
    endif else begin
      message, 'ERROR: cannot find file '+ filename
    endelse
  endif
;
; Open a varfile and read some data!
;
  openr, file, filename, /f77, swap_endian=swap_endian
  if (precision eq 'D') then bytes=8 else bytes=4
  if (f77 eq 0) then markers=0 else markers=2
  point_lun, file, long64(dim.mx)*long64(dim.my)*long64(dim.mz)*long64(mvar_io*bytes)+long64(markers*4)
  if (allprocs eq 1) then begin
    ; collectively written files
    readu, file, t, x, y, z, dx, dy, dz
  endif else if (allprocs eq 2) then begin
    ; xy-collectively written files for each ipz-layer
    readu, file, t
  endif else begin
    ; distributed files
    if (param.lshear) then begin
      readu, file, t, x, y, z, dx, dy, dz, deltay
    endif else begin
      readu, file, t, x, y, z, dx, dy, dz
    endelse
  endelse
;
  close,file
  free_lun,file
;
; If requested print a summary (actually the default - unless being quiet).
;
  if (not quiet) then print, ' t = ', t
  time = t
;
end
