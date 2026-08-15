#ifndef CSwissEphemeris_h
#define CSwissEphemeris_h

/* Upstream headers are not self-ordering (sweph.h depends on macros defined
   in swephexp.h with no include guard forcing the order), so this umbrella
   header pins the same dependency order the original sweph.c/swehouse.c/etc.
   use when they #include these files directly. Do not reorder. */
#include "sweodef.h"
#include "swephexp.h"
#include "sweph.h"
#include "swephlib.h"
#include "swehouse.h"
#include "swejpl.h"
#include "swemptab.h"
#include "swenut2000a.h"

#endif /* CSwissEphemeris_h */
