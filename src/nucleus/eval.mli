(** Evaluation of computations *)

(** Abstract a judgment. *)
val abstract :
  eval_u:(Environment.t -> 'a -> Tt.ty) ->
  eval_v:(Environment.t -> 'b -> 'c) ->
  abstract_u:(Name.atom list -> Tt.ty -> 'd) ->
  abstract_v:(Name.atom list -> 'c -> 'e) ->
  Environment.t ->
  (Name.ident * ('a * Location.t)) list -> 'b -> (Name.ident * 'd) list * 'e

(** [comp env c] evaluates computation [c] in environment [env]. *)
val comp : Environment.t -> Syntax.comp -> Value.result

(** [comp_value env] evaluates computation [c] in environment [env] and returns
    its value, or triggers a runtime error if the result is an operation. *)
val comp_value : Environment.t -> Syntax.comp -> Value.value

(** [comp_term env c] evaluates computation [c] in environment [env],
    checks that the result is a term and returns it. *)
val comp_term : Environment.t -> Syntax.comp -> Judgement.term

(** [comp_ty env c] evaluates computation [c] in environment [env],
    checks that the result is a type and returns it. *)
val comp_ty : Environment.t -> Syntax.comp -> Judgement.ty
