## ----------------------------------------------------------------------------
# t/0.loadxs.t
# -----------------------------------------------------------------------------
# $Id: 0.loadxs.t,v 1.4 2002/10/31 11:08:50 hio Exp $
# -----------------------------------------------------------------------------

use strict;
use Test;
BEGIN { plan tests => 3 }

# -----------------------------------------------------------------------------
# load module

require Unicode::Japanese;
ok(1,1,'require');

import Unicode::Japanese;
ok(1,1,'import');

# -----------------------------------------------------------------------------
# check XS was loaded.

# xs is loaded in first invocation of `new'.
Unicode::Japanese->new();
my $dummy = $Unicode::Japanese::xs_loaderror;
#skip($^O eq 'MSWin32'&&"XS is disabled on $^O",$Unicode::Japanese::xs_loaderror,'');
ok($Unicode::Japanese::xs_loaderror,'');

