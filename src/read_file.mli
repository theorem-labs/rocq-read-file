(** Public interface of the read-file plugin. *)

type file_source = FilePath of string | ExtraDepIdent of Names.Id.t

type endianness = LittleEndian | BigEndian

type slice = {
  offset : int option;  (** None means 0. *)
  length : int option;  (** None means "to end of file". *)
}

val no_slice : slice

val set_max_array_length : int -> unit
val reset_max_array_length : unit -> unit

val read_bytes :
  file_source -> Names.Id.t -> Libnames.qualid option -> slice -> unit

val read_int63 :
  file_source -> Names.Id.t -> endianness -> slice -> unit

val read_string :
  file_source -> Names.Id.t -> slice -> unit
