################
##
##	read
##
################

from .dim import dim
from .pdim import pdim, __Pdim__
from .param import param
from .grid import grid
from .index import index
from .var import var
from .slices import slices
from .ts import ts
from .averages import aver
from .ogdim import ogdim
from .ogvar import ogvar
del(averages)

# idl workarounds
from .pstalk import pstalk
from .pvar import pvar
