(** Accessing nested primitive arrays by a flat index.

    When [ReadFileBytes]/[ReadFileInt63]/[ReadFileString] auto-nest,
    the resulting type changes shape with depth.  These helpers let
    you index the structure as if it were flat, given the inner-array
    bound (typically [PArray.max_length] for byte/int63 nesting, or
    [Pstring.max_length] for string nesting).
*)

From ReadFile Require Import ReadFile.

Open Scope uint63_scope.

Module NestedArray.

  (** Depth-1 access (no nesting). *)
  Definition get1 {A} (a : array A) (i : int) : A := a.[i].

  (** Depth-2 access. [m] is the size used per inner block — pass
      [PArray.max_length] for arrays produced by the auto-nester. *)
  Definition get2 {A} (m : int) (a : array (array A)) (i : int) : A :=
    a.[i / m].[i mod m].

  (** Depth-3 access. [m1] is the inner-most block size, [m2] the
      next. Per the auto-nester these are equal to
      [PArray.max_length]. *)
  Definition get3 {A} (m1 m2 : int)
                  (a : array (array (array A))) (i : int) : A :=
    let q1 := i  / m1 in
    let r1 := i mod m1 in
    let q2 := q1 / m2 in
    let r2 := q1 mod m2 in
    a.[q2].[r2].[r1].

End NestedArray.
