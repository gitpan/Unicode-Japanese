
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
skip($^O eq 'MSWin32'&&"XS is disabled on $^O",$Unicode::Japanese::xs_loaderror,'');

