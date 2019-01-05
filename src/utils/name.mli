(** Variable names *)

(** The fixity classes charcterize the various kinds of identifiers. *)
type fixity =
  | Word (** an ordinary word *)
  | Anonymous of int (** an anonymous binder, written as [_] by the user *)
  | Prefix (** a prefix operator *)
  | Infix of Level.infix (** an infix operator of given level *)

type ident = private Ident of string * fixity

type atom = private Atom of string * fixity * int

type meta = private Meta of string * fixity * int

(** Aliases with different semantics *)

type constructor = ident

type aml_module = ident

type operation = ident

type ty = ident

type aml_constructor = ident

(** A name that is possibly qualified by a module *)
type 'a long = private Long of aml_module option * 'a

module Predefined : sig
  (** The name of the boolean type *)
  val bool : ty

  (** The name of the [mlfalse] constructor *)
  val mlfalse : aml_constructor

  (** The name of the [mltrue] constructor *)
  val mltrue : aml_constructor

  (** The name of the list type *)
  val list : ty

  (** The name [[]] constructor *)
  val nil : aml_constructor

  (** The name of the [::] constructor *)
  val cons : aml_constructor


  (** The name of the order type *)
  val mlorder : ty

  (** The names of order type tags *)
  val mlless : aml_constructor
  val mlequal : aml_constructor
  val mlgreater : aml_constructor

  (** The name of the option type *)
  val option : ty

  (** The name of the [Some] constructor *)
  val some : aml_constructor

  (** The name of the [None] constructor *)
  val none : aml_constructor

  (** The name of the [equal_term] operation *)
  val equal_term : operation

  (** The name of the [equal_type] operation *)
  val equal_type : operation

  (** The name of the [coercible] type *)
  val coercible_ty : ty

  (** The name of the [Coercible] constructor *)
  val coercible_constructor : aml_constructor

  (** The name of the [Convertible] constructor *)
  val convertible : aml_constructor

  (** The name of the [NotCoercible] constructor *)
  val notcoercible : aml_constructor

  (** The name of the [coerce] operation *)
  val coerce : operation

  (** The name of the [hypotheses] dynamic variable *)
  val hypotheses : ident
end

(** Convert an index to a greek letter, possibly with subscript. This is used
    for printing ML type parameters. *)
val greek : int -> string

(** Print a name. *)
val print_ident : ?parentheses:bool -> ident -> Format.formatter -> unit

(** Effectful: atoms are reindexed as they are encountered. *)
val print_atom : ?parentheses:bool -> atom -> Format.formatter -> unit

(** Effectful: metas are reindexed as they are encountered. *)
val print_meta : ?parentheses:bool -> meta -> Format.formatter -> unit

(** Print an operation name. *)
val print_op : ident -> Format.formatter -> unit

(** An new anonymous name that cannot be referenced by the user. *)
val anonymous : unit -> ident

(** The basename of a file nime associated with the given module name. *)
val module_filename : aml_module -> string

(** Make a name from a string. *)
val mk_ident : ?fixity:fixity -> string -> ident

(** Make a name without module information. *)
val mk_short : 'a -> 'a long

(** Make a name with module information. *)
val mk_long : aml_module -> 'a -> 'a long

(** Generate a variant of a given name that is guaranteed to not yet exist. *)
val fresh : ident -> atom

val ident_of_atom : atom -> ident

(** [refresh xs x] finds a nice variant of [x] that does not occur in [xs]. *)
val refresh : ident list -> ident -> ident

(** Compare identifiers for equality. *)
val eq_ident : ident -> ident -> bool

(** Compare identifiers. *)
val compare_ident : ident -> ident -> int

module IdentSet : Set.S with type elt = ident
module IdentMap : Map.S with type key = ident

(** Compare atoms for equality. *)
val eq_atom : atom -> atom -> bool

(** Compare atoms. *)
val compare_atom : atom -> atom -> int

module AtomSet : Set.S with type elt = atom
module AtomMap : Map.S with type key = atom

(** Generate a variant of a given name that is guaranteed to not yet exist. *)
val fresh_meta : ident -> meta

val ident_of_meta : meta -> ident

(** Compare metas for equality. *)
val eq_meta : meta -> meta -> bool

(** Compare metas. *)
val compare_meta : meta -> meta -> int

module MetaSet : Set.S with type elt = meta
module MetaMap : Map.S with type key = meta

(** [index_of_atom x xs] finds the index of [x] in list [xs] if it's there. *)
val index_of_atom : atom -> atom list -> int option

(** [index_of_ident x xs] finds the index of [x] in list [xs] if it's there. *)
val index_of_ident : ident -> ident list -> int option

(** [index_of_opt_ident x xs] finds the index of [x] in list of optional names [xs] if it's there. *)
val index_of_opt_ident : ident -> ident option list -> int option

(** [level_of_ident x xs] finds the level of [x] in list [xs] if it's there. *)
val level_of_ident : ident -> ident list -> int option

(** Like List.assoc, but using [eq_ident] and without exceptions. *)
val assoc_ident : ident -> (ident * 'a) list -> 'a option

val print_debruijn : ident list -> int -> Format.formatter -> unit

module Json :
sig
  (** Convert an identifier to JSON. *)
  val ident : ident -> Json.t

  (** Convert an atom to JSON. *)
  val atom : atom -> Json.t

  (** Convert a meta to JSON. *)
  val meta : meta -> Json.t

  (** Convert a set of atoms to JSON. *)
  val atomset : AtomSet.t -> Json.t

  (** Convert a map of atoms to JSON (dropping the values). *)
  val atommap : 'a AtomMap.t -> Json.t

  (** Convert a map of metas to JSON (dropping the values). *)
  val metamap : 'a MetaMap.t -> Json.t
end
