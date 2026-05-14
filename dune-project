(lang dune 3.8)
(using coq 0.8)

(name rocq-read-file)

(generate_opam_files true)

(license MIT)
(maintainers "Jason Gross <jason@theorem.dev>")
(authors "Jason Gross")
(source (github theorem-labs/rocq-read-file))
(bug_reports "https://github.com/theorem-labs/rocq-read-file/issues")
(homepage "https://github.com/theorem-labs/rocq-read-file")

(package
 (name rocq-read-file)
 (synopsis "Read files from disk into Rocq primitive values")
 (description
  "A Rocq plugin that reads binary files into Rocq-side primitive values: byte arrays, int63 arrays, or primitive strings. Auto-nests into primitive arrays when results exceed PArray.max_length.")
 (depends
  (ocaml (>= 4.09))
  (dune :build)
  (coq-core (>= 8.18))
  (coq-stdlib (>= 8.18))))
