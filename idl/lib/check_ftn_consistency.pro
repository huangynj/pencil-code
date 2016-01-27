  function check_ftn_consistency, file
;
; Checks whether <file> has a consistent FORTRAN record structure.
; Tries with swapped endian when failing with unswapped.
; Returns -1 for total failure, 0 and 1 for success with unswapped and swapped endian, respectively.
; Missing: considering of 8 byte record length markers.
;
; 27-jan-16/MR: coded
;
    swap=0
    while (1) do begin

      openr, 11, file, SWAP_ENDIAN=swap

      len1=0L & len2=len1 & len=0L

      fail=1

      while not eof(11) do begin

        readu, 11, len1
        if len1 le 0 then break

        len += len1+4L
        point_lun, 11, len
        if eof(11) then break

        readu, 11, len2
        if len2 le 0 then break $
        else if len2 ne len1 then break

        len +=4L
        fail=0

      endwhile

      close, 11
      if fail then begin
        if swap then $
          break $
        else $
          swap=1
      endif else $
        break

    endwhile

    if not fail then begin
      info=file_info(file)
      if info.size ne len then fail=1
    endif

    return, fail ? -1 : swap

  end

