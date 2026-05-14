(** Public interface of the read-file plugin. *)

type endianness = LittleEndian | BigEndian

type slice = {
  offset : int option;  (** None means 0. *)
  length : int option;  (** None means "to end of file". *)
}

val no_slice : slice

val set_max_array_length : int -> unit
val reset_max_array_length : unit -> unit

val read_bytes :
  string -> Names.Id.t -> Libnames.qualid option -> slice -> unit

val read_int63 :
  string -> Names.Id.t -> endianness -> slice -> unit

val read_string :
  string -> Names.Id.t -> slice -> unit
