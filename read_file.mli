(** Public interface of the read-file plugin. *)

type endianness = LittleEndian | BigEndian

type slice = {
  offset : int option;  (** None means 0. *)
  length : int option;  (** None means "to end of file". *)
}

val no_slice : slice

(** [read_bytes file name ty_opt slice] reads a (possibly sliced) byte
    range of [file] and defines [name] as a primitive array of those
    bytes. The element type is [Coq.Init.Byte.byte] when [ty_opt] is
    [None], otherwise [ty_opt] must resolve to a parameterless
    inductive type with exactly 256 nullary constructors (mapped
    positionally: byte [b] becomes the [(b+1)]-th constructor).

    If the slice is too large to fit in a single primitive array, the
    array is automatically nested in primitive arrays as deep as
    necessary. *)
val read_bytes :
  string -> Names.Id.t -> Libnames.qualid option -> slice -> unit

(** [read_int63 file name endian slice] reads the slice as a sequence
    of 8-byte chunks, each interpreted as an unsigned 64-bit integer
    in the given endianness, and stores them as a primitive array of
    [int63] values. The slice is right-padded with zero bytes if its
    length is not a multiple of 8. The high (64th) bit is silently
    dropped, since [int63] only carries 63 bits.

    Auto-nests when the result exceeds [PArray.max_length] elements. *)
val read_int63 :
  string -> Names.Id.t -> endianness -> slice -> unit

(** [read_string file name slice] reads the slice and stores it as a
    primitive string when it fits within [Pstring.max_length], or as
    a (possibly nested) primitive array of primitive strings when it
    does not. *)
val read_string :
  string -> Names.Id.t -> slice -> unit
