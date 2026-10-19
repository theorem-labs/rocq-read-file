[%%if rocq = "9.0" || rocq = "9.1"]
let univ_entry_mono sigma = Evd.univ_entry ~poly:false sigma
[%%else]
let univ_entry_mono sigma = Evd.univ_entry ~poly:PolyFlags.default sigma
[%%endif]
