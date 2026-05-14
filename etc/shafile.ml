let mk_ident =
  String.map (function '.' | '/' | '-' -> '_' | c -> c)

let () =
  let args = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
  Array.iter (fun file ->
    Printf.printf "Definition %s := \"%s\".\n"
      (mk_ident file) (Digest.to_hex (Digest.file file))) args
