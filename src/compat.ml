[%%if coq = "9.0" || coq = "9.1"]
let univ_entry_mono sigma = Evd.univ_entry ~poly:false sigma
[%%else]
let univ_entry_mono sigma = Evd.univ_entry ~poly:PolyFlags.default sigma
[%%endif]
