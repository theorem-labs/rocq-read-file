From Stdlib.Init Require Import Byte.
From Stdlib Require Import PArray Uint63 PrimString.
From Stdlib Require Import Nat.

Open Scope uint63_scope.

Polymorphic Fixpoint NestedArray (n : nat) (A : Type) : Type :=
  match n with
  | 0 => A
  | S n' => array (NestedArray n' A)
  end.

Fixpoint array_fold_left_nat {A B} (f : B -> int -> A -> B)
  (a : array A) (fuel : nat) (acc : B) (i : int) : B :=
  match fuel with
  | 0 => acc
  | S fuel' =>
    if (i <? PArray.length a)%uint63
    then array_fold_left_nat f a fuel' (f acc i a.[i]) (i + 1)
    else acc
  end.

Definition array_fold_left {A B} (f : B -> int -> A -> B)
  (a : array A) (acc : B) : B :=
  array_fold_left_nat f a (Uint63.to_nat (PArray.length a)) acc 0.

Fixpoint array_fold_left_early_nat {A B} (f : B -> int -> A -> option B)
  (a : array A) (fuel : nat) (acc : B) (i : int) : B :=
  match fuel with
  | 0 => acc
  | S fuel' =>
    if (i <? PArray.length a)%uint63
    then match f acc i a.[i] with
         | Some acc' => array_fold_left_early_nat f a fuel' acc' (i + 1)
         | None => acc
         end
    else acc
  end.

Definition array_init {A} (len : int) (default : A) (f : int -> A) : array A :=
  let dummy := PArray.make len default in
  array_fold_left (fun arr i _ => arr.[i <- f i]) dummy dummy.

Module NestedArray.

  Polymorphic Fixpoint get {n : nat} {A : Type}
    (a : NestedArray (S n) A) (i : int) {struct n} : A :=
    match n return NestedArray (S n) A -> A with
    | 0 => fun a => a.[i]
    | S n' => fun a =>
      let sz := PArray.length a.[0] in
      let sz := if (sz =? 0)%uint63 then PArray.max_length else sz in
      get a.[i / sz] (i mod sz)
    end a.

  Polymorphic Fixpoint length {n : nat} {A : Type}
    (a : NestedArray (S n) A) {struct n} : int :=
    match n return NestedArray (S n) A -> int with
    | 0 => fun a => PArray.length a
    | S n' => fun a =>
      let m := PArray.length a in
      if (m =? 0)%uint63 then 0
      else (m - 1) * length a.[0] + length a.[m - 1]
    end a.

  Polymorphic Fixpoint leaf_default {n : nat} {A : Type}
    (a : NestedArray (S n) A) {struct n} : A :=
    match n return NestedArray (S n) A -> A with
    | 0 => fun a => PArray.default a
    | S n' => fun a => leaf_default (PArray.default a)
    end a.

  Polymorphic Fixpoint rechunk {n : nat} {A : Type}
    (get_elem : int -> A) (total_len : int)
    (max_len : int) (inner_flat_cap : int) (default : A)
    {struct n} : NestedArray (S n) A :=
    match n return NestedArray (S n) A with
    | 0 => array_init total_len default get_elem
    | S n' =>
      let n_blocks := (total_len + inner_flat_cap - 1) / inner_flat_cap in
      let default_inner := rechunk (fun _ => default) 0 max_len
                                    (inner_flat_cap / max_len) default in
      array_init n_blocks default_inner (fun j =>
        let o := j * inner_flat_cap in
        let l := if (total_len - o <? inner_flat_cap)%uint63
                 then total_len - o else inner_flat_cap in
        rechunk (fun i => get_elem (o + i)) l max_len
                (inner_flat_cap / max_len) default)
    end.

  Fixpoint int_pow (base : int) (exp : nat) : int :=
    match exp with
    | 0 => 1
    | S e => base * int_pow base e
    end.

  Polymorphic Definition inner_block_size {n : nat} {A : Type}
    (a : NestedArray (S n) A) : int :=
    match n return NestedArray (S n) A -> int with
    | 0 => fun _ => PArray.max_length
    | S n' => fun a =>
      let a' : array (NestedArray (S n') A) := a in
      let sz := PArray.length a'.[0] in
      if (sz =? 0)%uint63 then PArray.max_length else sz
    end a.

  Definition sub {n : nat} {A : Type} (a : NestedArray (S n) A) (offset len : int)
    : NestedArray (S n) A :=
    let max_len := inner_block_size a in
    rechunk (fun i => get a (offset + i)) len max_len
            (int_pow max_len n) (leaf_default a).

  Definition cat {n : nat} {A : Type} (a b : NestedArray (S n) A)
    : NestedArray (S n) A :=
    let la := length a in
    let max_len := inner_block_size a in
    rechunk (fun i => if (i <? la)%uint63 then get a i else get b (i - la))
            (la + length b) max_len (int_pow max_len n) (leaf_default a).

  Definition array_compare {A : Type} (cmp : A -> A -> comparison)
    (a b : array A) : comparison :=
    let la := PArray.length a in
    let lb := PArray.length b in
    let min_len := if (la <? lb)%uint63 then la else lb in
    let dummy := PArray.make min_len a.[0] in
    let c := array_fold_left_nat
               (fun acc i _ =>
                  match acc with
                  | Eq => cmp a.[i] b.[i]
                  | _ => acc
                  end)
               dummy (Uint63.to_nat min_len) Eq 0 in
    match c with Eq => Uint63.compare la lb | _ => c end.

  Polymorphic Fixpoint compare {n : nat} {A : Type}
    (cmp : A -> A -> comparison)
    (a b : NestedArray (S n) A) {struct n} : comparison :=
    match n return NestedArray (S n) A -> NestedArray (S n) A -> comparison with
    | 0 => fun a b => array_compare cmp a b
    | S n' => fun a b => array_compare (compare cmp) a b
    end a b.

End NestedArray.
