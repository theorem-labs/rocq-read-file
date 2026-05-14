(** Implementation of the read-file plugin. *)

open Names

type endianness = LittleEndian | BigEndian

type slice = { offset : int option; length : int option }
let no_slice = { offset = None; length = None }

(* ================================================================== *)
(* File I/O                                                           *)
(* ================================================================== *)

let resolve_path (path : string) : string =
  if Sys.file_exists path then path
  else
    let from_loadpath =
      try Some (Loadpath.locate_file path)
      with Not_found -> None
    in
    match from_loadpath with
    | Some resolved -> resolved
    | None -> path

let read_slice (path : string) (sl : slice) : bytes =
  let path = resolve_path path in
  let ic =
    try open_in_bin path
    with Sys_error msg ->
      CErrors.user_err Pp.(str "Cannot open file: " ++ str msg)
  in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
       let total = in_channel_length ic in
       let off = match sl.offset with None -> 0 | Some o -> o in
       if off < 0 then
         CErrors.user_err
           Pp.(str "Negative offset: " ++ int off ++ str ".");
       if off > total then
         CErrors.user_err
           Pp.(str "Offset " ++ int off
               ++ str " is past end of file (size " ++ int total
               ++ str ").");
       let len =
         match sl.length with
         | None -> total - off
         | Some l ->
           if l < 0 then
             CErrors.user_err
               Pp.(str "Negative length: " ++ int l ++ str ".");
           if off + l > total then
             CErrors.user_err
               Pp.(str "Slice [" ++ int off ++ str ".."
                   ++ int (off + l)
                   ++ str ") exceeds file size " ++ int total
                   ++ str ".");
           l
       in
       seek_in ic off;
       let buf = Bytes.create len in
       really_input ic buf 0 len;
       buf)

(* ================================================================== *)
(* Looking up registered or named globals                             *)
(* ================================================================== *)

let try_lib_refs (keys : string list) : GlobRef.t option =
  let rec loop = function
    | [] -> None
    | k :: rest ->
      try Some (Rocqlib.lib_ref k) with _ -> loop rest
  in
  loop keys

let locate_first (qids : string list) : GlobRef.t option =
  let rec loop = function
    | [] -> None
    | q :: rest ->
      try Some (Nametab.locate (Libnames.qualid_of_string q))
      with Not_found -> loop rest
  in
  loop qids

let lookup_qualid_ind (qid : Libnames.qualid) : inductive =
  let gr =
    try Nametab.locate qid
    with Not_found ->
      CErrors.user_err
        Pp.(str "Cannot resolve: " ++ Libnames.pr_qualid qid)
  in
  match gr with
  | GlobRef.IndRef ind -> ind
  | _ ->
    CErrors.user_err
      Pp.(str "Not an inductive type: " ++ Libnames.pr_qualid qid)

let must_const ~what gr_opt : Constant.t =
  match gr_opt with
  | Some (GlobRef.ConstRef c) -> c
  | _ ->
    CErrors.user_err
      Pp.(str "Cannot find " ++ str what
          ++ str ". Make sure the relevant module has been required.")

let default_byte_inductive () : inductive =
  match try_lib_refs ["core.byte.type"] with
  | Some (GlobRef.IndRef ind) -> ind
  | _ ->
    match locate_first ["Byte.byte"; "Corelib.Init.Byte.byte"; "Stdlib.Init.Byte.byte"] with
    | Some (GlobRef.IndRef ind) -> ind
    | _ ->
      CErrors.user_err
        Pp.(str "Cannot find Byte.byte. \
                 Make sure to Require Import Byte.")

let array_constant () : Constant.t =
  let opt =
    match try_lib_refs ["array.array"; "core.array.type"] with
    | Some _ as o -> o
    | None ->
      locate_first
        ["array";
         "Corelib.Array.PrimArray.array";
         "PrimArray.array";
         "PArray.array";
         "Stdlib.Array.PArray.array"]
  in
  must_const ~what:"the primitive array type" opt

let int63_type_constant () : Constant.t =
  let opt =
    match try_lib_refs ["num.int63.type"; "core.int63.type"] with
    | Some _ as o -> o
    | None ->
      locate_first
        ["int";
         "Corelib.Numbers.Cyclic.Int63.PrimInt63.int";
         "PrimInt63.int"; "Uint63.int";
         "Stdlib.Numbers.Cyclic.Int63.PrimInt63.int"]
  in
  must_const ~what:"the primitive int63 type" opt

let pstring_type_constant () : Constant.t =
  let opt =
    match try_lib_refs ["core.pstring.type"; "core.string.type"] with
    | Some _ as o -> o
    | None ->
      locate_first
        ["string";
         "Corelib.Strings.PrimString.string";
         "PrimString.string";
         "Stdlib.Strings.PrimString.string"]
  in
  must_const ~what:"the primitive string type" opt

(* ================================================================== *)
(* Validation of byte-compatible inductives                           *)
(* ================================================================== *)

let check_byte_compatible env (ind : inductive) =
  let mib, oib = Inductive.lookup_mind_specif env ind in
  if Array.length mib.Declarations.mind_packets <> 1 then
    CErrors.user_err
      Pp.(str "Mutual inductive types are not supported.");
  if mib.Declarations.mind_nparams <> 0 then
    CErrors.user_err
      Pp.(str "A byte-like inductive must take no parameters; "
          ++ MutInd.print (fst ind)
          ++ str " takes "
          ++ int mib.Declarations.mind_nparams ++ str ".");
  let nctors = Array.length oib.Declarations.mind_consnames in
  if nctors <> 256 then
    CErrors.user_err
      Pp.(str "A byte-like inductive must have exactly 256 \
               constructors; "
          ++ MutInd.print (fst ind)
          ++ str " has "
          ++ int nctors ++ str ".");
  Array.iteri
    (fun i nargs ->
       if nargs <> 0 then
         CErrors.user_err
           Pp.(str "All constructors must be nullary; constructor #"
               ++ int (i + 1) ++ str " ("
               ++ Id.print oib.Declarations.mind_consnames.(i)
               ++ str ") has "
               ++ int nargs ++ str " argument(s)."))
    oib.Declarations.mind_consnrealargs

let byte_constructor_constrs (ind : inductive) : Constr.t array =
  Array.init 256 (fun i -> Constr.UnsafeMonomorphic.mkConstruct (ind, i + 1))

(* ================================================================== *)
(* Primitive-array term construction                                  *)
(* ================================================================== *)

(* The primitive [array]'s single universe parameter is always
   instantiated at [Set]. Both [byte] and [int63] live there, as does
   [Pstring.string], and we require any user-supplied byte-like
   inductive to live there as well. *)
let array_set_instance () : UVars.Instance.t =
  UVars.Instance.of_array ([||], [| Univ.Level.set |])

let make_array_term ~elements ~default ~elem_type : Constr.t =
  let inst = array_set_instance () in
  Constr.mkArray (inst, elements, default, elem_type)

let make_array_type ~elem_type : Constr.types =
  let array_c = array_constant () in
  let inst = array_set_instance () in
  Constr.mkApp (Constr.mkConstU (array_c, inst), [| elem_type |])

let default_max_array_length = 4194302
let max_array_length = ref default_max_array_length

let set_max_array_length n =
  if n <= 0 then
    CErrors.user_err
      Pp.(str "MaxArrayLength must be positive; got " ++ int n ++ str ".");
  if n > 4194302 then
    CErrors.user_err
      Pp.(str "MaxArrayLength cannot exceed PArray.max_length (4194302); got "
          ++ int n ++ str ".");
  max_array_length := n

let reset_max_array_length () =
  max_array_length := default_max_array_length

(* ------------------------------------------------------------------ *)
(* Auto-nesting builder                                               *)
(* ------------------------------------------------------------------ *)

(* If [elements] fits in one primitive array, wrap it.  Otherwise
   chunk into [max_array_length]-sized blocks, wrap each block in a
   primitive array, and recurse with those arrays as the new elements.

   At every recursion the count shrinks by a factor of
   [max_array_length], so this terminates in
   ceil(log_M(N)) levels (M = max_array_length).  In practice 1 or 2
   levels suffice for files up to ~16 TB. *)
let rec build_nested_array
    ~elem_type ~elem_default (elements : Constr.t array)
    : Constr.t * Constr.types =
  let n = Array.length elements in
  if n <= !max_array_length then
    let body = make_array_term ~elements ~default:elem_default ~elem_type in
    let typ  = make_array_type  ~elem_type in
    (body, typ)
  else begin
    let m = !max_array_length in
    let n_chunks = (n + m - 1) / m in
    let chunks =
      Array.init n_chunks (fun i ->
        let start = i * m in
        let stop  = min n (start + m) in
        let chunk = Array.sub elements start (stop - start) in
        make_array_term ~elements:chunk ~default:elem_default ~elem_type)
    in
    let inner_type = make_array_type ~elem_type in
    let inner_default =
      make_array_term ~elements:[||] ~default:elem_default ~elem_type
    in
    build_nested_array
      ~elem_type:inner_type ~elem_default:inner_default
      chunks
  end

(* ================================================================== *)
(* Primitive-string term construction                                 *)
(* ================================================================== *)

let pstring_max_length = Pstring.max_length_int

(* NB: depending on Rocq version, [Pstring.of_string] may return
   [Pstring.t option] (signalling overflow) or [Pstring.t] directly.
   We always pre-validate the length, so the failure branch is never
   taken in normal operation. If the API in your tree is non-optional,
   replace the body with [Constr.mkString (Pstring.of_string s)]. *)
let make_pstring_term (s : string) : Constr.t =
  match Pstring.of_string s with
  | Some p -> Constr.mkString p
  | None ->
    CErrors.user_err
      Pp.(str "Internal error: primitive-string overflow at length "
          ++ int (String.length s))

let pstring_type_term () : Constr.types =
  Constr.UnsafeMonomorphic.mkConst (pstring_type_constant ())

(* ================================================================== *)
(* Declaring the resulting global                                     *)
(* ================================================================== *)

let declare_def ~env ~name ~typ ~body =
  let sigma = Evd.from_env env in
  let univs = Evd.univ_entry ~poly:PolyFlags.default sigma in
  let entry = Declare.definition_entry ~univs ~types:typ body in
  let _kn =
    Declare.declare_constant
      ~name
      ~kind:Decls.(IsDefinition Definition)
      (Declare.DefinitionEntry entry)
  in
  Feedback.msg_info
    Pp.(str "Defined "
        ++ Id.print name
        ++ str " : "
        ++ Printer.pr_constr_env env sigma typ)

(* ================================================================== *)
(* Public entry point: read_bytes                                     *)
(* ================================================================== *)

let read_bytes
    (file : string) (name : Id.t)
    (ty_opt : Libnames.qualid option) (sl : slice) : unit =
  let env = Global.env () in
  let raw = read_slice file sl in
  let ind =
    match ty_opt with
    | None     -> default_byte_inductive ()
    | Some qid -> lookup_qualid_ind qid
  in
  check_byte_compatible env ind;
  let n = Bytes.length raw in
  let ctors = byte_constructor_constrs ind in
  let elem_type = Constr.UnsafeMonomorphic.mkInd ind in
  let elements =
    Array.init n (fun i -> ctors.(Char.code (Bytes.get raw i)))
  in
  let elem_default = ctors.(0) in
  let body, typ =
    build_nested_array ~elem_type ~elem_default elements
  in
  declare_def ~env ~name ~typ ~body

(* ================================================================== *)
(* Public entry point: read_int63                                     *)
(* ================================================================== *)

let pad_bytes_to_multiple_of_8 (raw : bytes) : bytes =
  let n = Bytes.length raw in
  let r = n mod 8 in
  if r = 0 then raw
  else begin
    let padded = Bytes.make (n + (8 - r)) '\x00' in
    Bytes.blit raw 0 padded 0 n;
    padded
  end

let read_uint63_le (buf : bytes) (off : int) : Uint63.t =
  let acc = ref 0L in
  for i = 7 downto 0 do
    let b = Char.code (Bytes.get buf (off + i)) in
    acc := Int64.logor (Int64.shift_left !acc 8) (Int64.of_int b)
  done;
  Uint63.of_int64 !acc

let read_uint63_be (buf : bytes) (off : int) : Uint63.t =
  let acc = ref 0L in
  for i = 0 to 7 do
    let b = Char.code (Bytes.get buf (off + i)) in
    acc := Int64.logor (Int64.shift_left !acc 8) (Int64.of_int b)
  done;
  Uint63.of_int64 !acc

let read_int63
    (file : string) (name : Id.t)
    (endian : endianness) (sl : slice) : unit =
  let env = Global.env () in
  let raw = read_slice file sl in
  let raw = pad_bytes_to_multiple_of_8 raw in
  let m = Bytes.length raw / 8 in
  let read =
    match endian with
    | LittleEndian -> read_uint63_le
    | BigEndian    -> read_uint63_be
  in
  let elements =
    Array.init m (fun i -> Constr.mkInt (read raw (i * 8)))
  in
  let elem_default = Constr.mkInt (Uint63.of_int 0) in
  let elem_type = Constr.UnsafeMonomorphic.mkConst (int63_type_constant ()) in
  let body, typ =
    build_nested_array ~elem_type ~elem_default elements
  in
  declare_def ~env ~name ~typ ~body

(* ================================================================== *)
(* Public entry point: read_string                                    *)
(* ================================================================== *)

let read_string
    (file : string) (name : Id.t) (sl : slice) : unit =
  let env = Global.env () in
  let raw = read_slice file sl in
  let n = Bytes.length raw in
  let pstring_t = pstring_type_term () in
  if n <= pstring_max_length then begin
    let body = make_pstring_term (Bytes.unsafe_to_string raw) in
    declare_def ~env ~name ~typ:pstring_t ~body
  end else begin
    let m = pstring_max_length in
    let n_chunks = (n + m - 1) / m in
    let elements =
      Array.init n_chunks (fun i ->
        let start = i * m in
        let stop  = min n (start + m) in
        let chunk = Bytes.sub_string raw start (stop - start) in
        make_pstring_term chunk)
    in
    let elem_default = make_pstring_term "" in
    let body, typ =
      build_nested_array ~elem_type:pstring_t ~elem_default elements
    in
    declare_def ~env ~name ~typ ~body
  end
