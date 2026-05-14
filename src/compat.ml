[%%if coq = "8.18" || coq = "8.19" || coq = "8.20"]
module GramPrim = Pcoq.Prim
module Rocqlib = Coqlib
[%%else]
module GramPrim = Procq.Prim
module Rocqlib = Rocqlib
[%%endif]

[%%if coq = "8.18" || coq = "8.19" || coq = "8.20" || coq = "9.0" || coq = "9.1"]
let univ_entry_mono sigma = Evd.univ_entry ~poly:false sigma
[%%else]
let univ_entry_mono sigma = Evd.univ_entry ~poly:PolyFlags.default sigma
[%%endif]
