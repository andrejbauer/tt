(** Abstract syntax of computations and expressions. *)

type expr = expr' * Position.t
 and expr' =
   | Name of Common.name
   | Bound of Common.bound
   | Meta of Common.bound
   | Type

and ty = expr

and comp = comp' * Position.t
and comp' = 
  | Return of expr
  | Let of (Common.name * comp) list * comp
  | Ascribe of comp * ty
  | Lambda of (Common.name * ty) list * comp
  | Spine of expr * expr list
  | Prod of (Common.name * ty) list * comp
  | Eq of expr * comp
  | Refl of expr

(** Toplevel commands *)
type toplevel = toplevel' * Position.t
and toplevel' =
  | Parameter of Common.name list * comp (** introduce parameters into the context *)
  | TopLet of Common.name * comp (** global let binding *)
  | TopCheck of comp (** infer the type of a computation *)
  | Quit
  | Help
  | Context

