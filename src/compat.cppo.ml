#if COQ_VERSION_VERSION >= (9, 0, 0)
module GramPrim = Procq.Prim
#else
module GramPrim = Pcoq.Prim
#endif

#if COQ_VERSION_VERSION >= (9, 2, 0)
let univ_entry_mono sigma = Evd.univ_entry ~poly:PolyFlags.default sigma
#else
let univ_entry_mono sigma = Evd.univ_entry ~poly:false sigma
#endif
