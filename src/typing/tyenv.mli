(** The full typing environment. *)

(** The type of typing environments: a typing context together with a
    substitution and unsolved constraints. *)
type t

(** A type for signaling whether a thing is a judgement or a boundary *)
type judgement_or_boundary =
  | Is_judgement
  | Is_boundary

(** A type for signaling whether a thing is a derivation or a function *)
type derivation_or_function =
  | Is_derivation
  | Is_function of Mlty.ty * Mlty.ty

(** The empty typing environment. *)
val empty : t

(** A monadic type to make environment management easier while checking computations. *)
type 'a tyenvM

(** Monadic return. *)
val return : 'a -> 'a tyenvM

(** Monadic bind. *)
val (>>=) : 'a tyenvM -> ('a -> 'b tyenvM) -> 'b tyenvM

val run : t -> 'a tyenvM -> t * 'a

(** Lookup a bound variable by its De Bruijn index and instantiate its type parameters
   with fresh metavariables. *)
val lookup_bound : Path.index -> Mlty.ty tyenvM

(** Lookup an ML value and instantiate its type parameters with fresh metavariables. *)
val lookup_ml_value : Path.t -> Mlty.ty tyenvM

(** Lookup an operation and return the expected types of its arguments and the type it
   returns. *)
val lookup_ml_operation : Path.t -> (Ident.t * (Mlty.ty list * Mlty.ty)) tyenvM

(** Lookup an ML exception and return its typing information. *)
val lookup_ml_exception : Path.t -> (Ident.t * Mlty.ty option) tyenvM

(** Lookup an ML constructor and return the expected types of its arguments and the type
   it returns. *)
val lookup_ml_constructor : Path.ml_constructor -> (Ident.t * Mlty.ty list * Mlty.ty) tyenvM

(** Lookup a TT constructor and return its expected form. *)
val lookup_tt_constructor : Path.t -> Ident.t tyenvM

(** Add a TT constructor to the typing context, globally forever. *)
val add_tt_constructor : Ident.t -> unit tyenvM

(** [add_equation ~loc t1 t2] try to unify the actual type [t1] with the expected type
    [t2]. If successful, retry to solve the current unsolved constraints. *)
val add_equation : at:Location.t -> Mlty.ty -> Mlty.ty -> unit tyenvM

(** Express the given type as a judgement or a boundary. Report an error if neither
    can be determined. *)
val as_judgement_or_boundary : at:Location.t -> Mlty.ty -> judgement_or_boundary tyenvM

(** Express the given type either as a derivation or a function, preferring the function
    case when the chocie is not determined yet. *)
val as_derivation_or_function : at:Location.t -> Mlty.ty -> derivation_or_function tyenvM

(** Express the given type as a handler type. *)
val as_handler : at:Location.t -> Mlty.ty -> (Mlty.ty * Mlty.ty) tyenvM

(** Express the given type as a reference type. *)
val as_ref : at:Location.t -> Mlty.ty -> Mlty.ty tyenvM

(** Generalize the given type as much as possible in the current environment, possibly
   solving unification problems. *)
val generalize : Mlty.ty -> Mlty.ty_schema tyenvM

(** Check that the given type can be generalized to the given schema in the current
   environment, possibly solving unification problems. *)
val generalizes_to : at:Location.t -> Mlty.ty -> Mlty.ty_schema -> unit tyenvM

(** Return the given type as a schema without generalizing anything. *)
val ungeneralize : Mlty.ty -> Mlty.ty_schema tyenvM

(** Apply the current substitution to the given schema. *)
(* val normalize_schema : Mlty.ty_schema -> Mlty.ty_schema tyenvM *)

(** Locally [let]-bind a variable with a polymorphic type and run a computation
    in the resulting context. *)
val add_bound_poly : Name.t -> Mlty.ty_schema -> 'a tyenvM -> 'a tyenvM

(** Like [add_bound_poly] with multiple bindings: we first bind the head of the list. *)
val add_bounds_poly : (Name.t * Mlty.ty_schema) list -> 'a tyenvM -> 'a tyenvM

(** Locally [let]-bind a variable with a monomorphic type and run a computation in the
   resulting context. *)
val add_bound_mono : Name.t -> Mlty.ty -> 'a tyenvM -> 'a tyenvM

(** Like [add_bound_mono] with multiple bindings: we first bind the head of the list. *)
val add_bounds_mono : (Name.t * Mlty.ty) list -> 'a tyenvM -> 'a tyenvM

(** Bind an ML value with a polymorphic type. *)
val add_ml_value_poly : Name.t -> Mlty.ty_schema -> 'a tyenvM -> 'a tyenvM

(** Like [add_ml_value_poly] with multiple bindings: we first bind the head of the list. *)
val add_ml_values_poly : (Name.t * Mlty.ty_schema) list -> 'a tyenvM -> 'a tyenvM

(** Bind an ML value with a monomorphic type. *)
val add_ml_value_mono : Name.t -> Mlty.ty -> 'a tyenvM -> 'a tyenvM

(** Define a new type. The type definition may refer to not-yet-defined types, relying on the caller to add them afterwards. *)
val add_ml_type : Path.t -> Mlty.ty_def -> unit tyenvM

(** Declare a new operation. *)
val add_ml_operation : Path.t -> Mlty.ty list * Mlty.ty -> unit tyenvM

(** Declare a new exception. *)
val add_ml_exception : Path.t -> Mlty.ty option -> unit tyenvM

(** Monadically wrap a computation with [Context.push_ml_module] and [Context.pop_ml_module]. *)
val as_module : 'a tyenvM -> 'a tyenvM
