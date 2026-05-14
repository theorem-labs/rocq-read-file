let () =
  let args = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
  Array.iter (fun file ->
    Printf.printf "(* %s: %s *)\n"
      file (Digest.to_hex (Digest.file file))) args
