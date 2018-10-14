
let (>>=) = Runtime.bind
let return = Runtime.return

(** Matching *)

exception Match_fail

let add_var x (v : Runtime.value) xvs = (x, v) :: xvs

(* There is a lot of repetition in the [collect_is_XYZ] functions below,
   but this seems to be the price to pay for the discrepancy between the
   syntax of patterns and the structure of runtime values. *)

let rec collect_is_term env xvs {Location.thing=p';loc} v =
  match p' with
  (* patterns that are generic for all judgement forms *)
  | Pattern.TTAnonymous -> xvs

  | Pattern.TTVar x ->
     add_var x (Runtime.mk_is_term v) xvs

  | Pattern.TTAs (p1, p2) ->
     let xvs = collect_is_term env xvs p1 v in
     collect_is_term env xvs p2 v

  (* patterns specific to terms *)
  | Pattern.TTConstructor (c, ps) ->
     begin match Jdg.invert_is_term_abstraction v with
     | Jdg.Abstract _ -> raise Match_fail
     | Jdg.NotAbstract e ->
        let sgn = Runtime.get_signature env in
        begin match Jdg.invert_is_term sgn e with
        | Jdg.TermConstructor (c', args) when Name.eq_ident c c' ->
           collect_args env xvs ps args
        | (Jdg.TermConstructor _ | Jdg.TermAtom _ | Jdg.TermConvert _) ->
           raise Match_fail
        end
     end

  | Pattern.TTGenAtom p ->
     begin match Jdg.invert_is_term_abstraction v with
     | Jdg.Abstract _ -> raise Match_fail
     | Jdg.NotAbstract e ->
        let sgn = Runtime.get_signature env in
        begin match Jdg.invert_is_term sgn e with
        | Jdg.TermAtom a ->
           collect_is_term env xvs p v
        | (Jdg.TermConstructor  _ | Jdg.TermConvert _) ->
           raise Match_fail
        end
     end

  | Pattern.TTIsTerm (p1, p2) ->
     let xvs = collect_is_term env xvs p1 v in
     (* TODO optimize for the case when [p2] is [Pattern.TTAnonymous]
        because it allows us to avoid calculating the type of [v]. *)
     let sgn = Runtime.get_signature env in
     let t = Jdg.type_of_term_abstraction sgn v in
     collect_is_type env xvs p2 t

  | Pattern.TTAbstract (xopt, p1, p2) ->
     begin match Jdg.invert_is_term_abstraction v with
     | Jdg.NotAbstract _ -> raise Match_fail
     | Jdg.Abstract (a, v2) ->
        let v1 = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.type_of_atom a)) in
        let xvs = collect_is_type env xvs p1 v1 in
        let xvs =
          match xopt with
          | None -> xvs
          | Some x ->
             let e = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.form_is_term_atom a)) in
             add_var x (Runtime.mk_is_term e) xvs
        in
        collect_is_term env xvs p2 v
     end

  | (Pattern.TTEqType _ | Pattern.TTEqTerm _ | Pattern.TTIsType _) ->
     raise Match_fail

and collect_is_type env xvs {Location.thing=p';loc} v =
  match p' with
  (* patterns that are generic for all judgement forms *)
  | Pattern.TTAnonymous -> xvs

  | Pattern.TTVar x ->
     add_var x (Runtime.mk_is_type v) xvs

  | Pattern.TTAs (p1, p2) ->
     let xvs = collect_is_type env xvs p1 v in
     collect_is_type env xvs p2 v

  (* patterns specific to types *)
  | Pattern.TTConstructor (c, ps) ->
     begin match Jdg.invert_is_type_abstraction v with
     | Jdg.Abstract _ -> raise Match_fail
     | Jdg.NotAbstract t ->
        begin match Jdg.invert_is_type t with
        | Jdg.TypeConstructor (c', args) ->
           if Name.eq_ident c c' then
             collect_args env xvs ps args
           else
             raise Match_fail
        end
     end

  | Pattern.TTAbstract (xopt, p1, p2) ->
     begin match Jdg.invert_is_type_abstraction v with
     | Jdg.NotAbstract _ -> raise Match_fail
     | Jdg.Abstract (a, v2) ->
        let v1 = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.type_of_atom a)) in
        let xvs = collect_is_type env xvs p1 v1 in
        let xvs =
          match xopt with
          | None -> xvs
          | Some x ->
             let e = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.form_is_term_atom a)) in
             add_var x (Runtime.mk_is_term e) xvs
        in
        collect_is_type env xvs p2 v
     end

  | (Pattern.TTIsTerm _ | Pattern.TTGenAtom _ | Pattern.TTEqType _ |
     Pattern.TTEqTerm _ | Pattern.TTIsType _) ->
     raise Match_fail

and collect_eq_type env xvs {Location.thing=p';loc} v =
  match p' with
  (* patterns that are generic for all judgement forms *)
  | Pattern.TTAnonymous -> xvs

  | Pattern.TTVar x ->
     add_var x (Runtime.mk_eq_type v) xvs

  | Pattern.TTAs (p1, p2) ->
     let xvs = collect_eq_type env xvs p1 v in
     collect_eq_type env xvs p2 v

  (* patterns specific to type equations *)
  | Pattern.TTAbstract (xopt, p1, p2) ->
     begin match Jdg.invert_eq_type_abstraction v with
     | Jdg.NotAbstract _ -> raise Match_fail
     | Jdg.Abstract (a, v2) ->
        let v1 = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.type_of_atom a)) in
        let xvs = collect_is_type env xvs p1 v1 in
        let xvs =
          match xopt with
          | None -> xvs
          | Some x ->
             let e = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.form_is_term_atom a)) in
             add_var x (Runtime.mk_is_term e) xvs
        in
        collect_eq_type env xvs p2 v
     end

  | Pattern.TTEqType (p1, p2) ->
     begin match Jdg.invert_eq_type_abstraction v with
     | Jdg.Abstract _ -> raise Match_fail
     | Jdg.NotAbstract eq ->
        let (Jdg.EqType (_asmp, t1, t2)) = Jdg.invert_eq_type eq in
        let xvs = collect_is_type env xvs p1 (Jdg.form_abstraction (Jdg.NotAbstract t1)) in
        collect_is_type env xvs p2 (Jdg.form_abstraction (Jdg.NotAbstract t2))
     end

  | (Pattern.TTIsTerm _ | Pattern.TTGenAtom _ | Pattern.TTEqTerm _ | Pattern.TTIsType _ |
     Pattern.TTConstructor _) ->
     raise Match_fail

and collect_eq_term env xvs {Location.thing=p';loc} v =
  match p' with
  (* patterns that are generic for all judgement forms *)
  | Pattern.TTAnonymous -> xvs

  | Pattern.TTVar x ->
     add_var x (Runtime.mk_eq_term v) xvs

  | Pattern.TTAs (p1, p2) ->
     let xvs = collect_eq_term env xvs p1 v in
     collect_eq_term env xvs p2 v

  (* patterns specific to term equations *)
  | Pattern.TTAbstract (xopt, p1, p2) ->
     begin match Jdg.invert_eq_term_abstraction v with
     | Jdg.NotAbstract _ -> raise Match_fail
     | Jdg.Abstract (a, v2) ->
        let v1 = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.type_of_atom a)) in
        let xvs = collect_is_type env xvs p1 v1 in
        let xvs =
          match xopt with
          | None -> xvs
          | Some x ->
             let e = Jdg.form_abstraction (Jdg.NotAbstract (Jdg.form_is_term_atom a)) in
             add_var x (Runtime.mk_is_term e) xvs
        in
        collect_eq_term env xvs p2 v
     end

  | Pattern.TTEqTerm (p1, p2, p3) ->
     begin match Jdg.invert_eq_term_abstraction v with
     | Jdg.Abstract _ -> raise Match_fail
     | Jdg.NotAbstract eq ->
        let (Jdg.EqTerm (_asmp, e1, e2, t)) = Jdg.invert_eq_term eq in
        let xvs = collect_is_term env xvs p1 (Jdg.form_abstraction (Jdg.NotAbstract e1)) in
        let xvs = collect_is_term env xvs p2 (Jdg.form_abstraction (Jdg.NotAbstract e2)) in
        collect_is_type env xvs p2 (Jdg.form_abstraction (Jdg.NotAbstract t))
     end

  | (Pattern.TTIsTerm _ | Pattern.TTGenAtom _ | Pattern.TTEqType _ | Pattern.TTIsType _ |
     Pattern.TTConstructor _) ->
     raise Match_fail

and collect_args env xvs ps vs =
  match ps, vs with

  | [], [] -> xvs

  | p::ps, v::vs ->
     let xvs =
       begin match v with
       | Jdg.PremiseIsType t -> collect_is_type env xvs p t
       | Jdg.PremiseIsTerm e -> collect_is_term env xvs p e
       | Jdg.PremiseEqType eq -> collect_eq_type env xvs p eq
       | Jdg.PremiseEqTerm eq -> collect_eq_term env xvs p eq
     end in
     collect_args env xvs ps vs

  | [], _::_ | _::_, [] -> assert false

and collect_pattern env xvs {Location.thing=p';loc} v =
  match p', v with
  | Pattern.Anonymous, _ -> xvs

  | Pattern.Var x, v ->
     add_var x v xvs

  | Pattern.As (p1, p2), v ->
     let xvs = collect_pattern env xvs p1 v in
     collect_pattern env xvs p2 v

  | Pattern.Judgement p, Runtime.IsType t ->
     collect_is_type env xvs p t

  | Pattern.Judgement p, Runtime.IsTerm e ->
     collect_is_term env xvs p e

  | Pattern.Judgement p, Runtime.EqType eq ->
     collect_eq_type env xvs p eq

  | Pattern.Judgement p, Runtime.EqTerm eq ->
     collect_eq_term env xvs p eq

  | Pattern.AMLConstructor (tag, ps), Runtime.Tag (tag', vs) when Name.eq_ident tag tag' ->
    multicollect_pattern env xvs ps vs

  | Pattern.Tuple ps, Runtime.Tuple vs ->
    multicollect_pattern env xvs ps vs

  (* mismatches *)
  | Pattern.Judgement _, (Runtime.Closure _ | Runtime.Handler _ | Runtime.Tag _ |
                          Runtime.Ref _ | Runtime.Dyn _ |
                          Runtime.Tuple _ | Runtime.String _)

  | Pattern.AMLConstructor _, (Runtime.IsTerm _ | Runtime.IsType _ | Runtime.EqTerm _ | Runtime.EqType _ |
                               Runtime.Closure _ | Runtime.Handler _ | Runtime.Tag _ |
                               Runtime.Ref _ | Runtime.Dyn _ |
                               Runtime.Tuple _ | Runtime.String _)

  | Pattern.Tuple _, (Runtime.IsTerm _ | Runtime.IsType _ | Runtime.EqTerm _ | Runtime.EqType _ |
                      Runtime.Closure _ | Runtime.Handler _ | Runtime.Tag _ |
                      Runtime.Ref _ | Runtime.Dyn _ | Runtime.String _) ->
     raise Match_fail

and multicollect_pattern env xvs ps vs =
  let rec fold xvs = function
    | [], [] -> xvs
    | p::ps, v::vs ->
      let xvs = collect_pattern env xvs p v in
      fold xvs (ps, vs)
    | ([], _::_ | _::_, []) ->
      raise Match_fail
  in
  fold xvs (ps, vs)

let match_pattern_env p v env =
  try
    let xvs = collect_pattern env [] p v in
    (* return in decreasing de bruijn order: ready to fold with add_bound *)
    let xvs = List.sort (fun (k,_) (k',_) -> compare k k') xvs in
    let xvs = List.rev_map snd xvs in
    Some xvs
  with
    Match_fail -> None

let top_match_pattern p v =
  let (>>=) = Runtime.top_bind in
  Runtime.top_get_env >>= fun env ->
    let r = match_pattern_env p v env  in
    Runtime.top_return r

let match_pattern p v =
  (* collect values of pattern variables *)
  Runtime.get_env >>= fun env ->
  let r = match_pattern_env p v env  in
  return r


let match_op_pattern ps pt vs checking =
  Runtime.get_env >>= fun env ->
  let r = begin try
    let xvs = multicollect_pattern env [] ps vs in
    let xvs = match pt with
      | None -> xvs
      | Some p ->
        let v = match checking with
          | Some j -> Predefined.from_option (Some (Runtime.mk_is_type j))
          | None -> Predefined.from_option None
       in
       collect_pattern env xvs p v
    in
    (* return in decreasing de bruijn order: ready to fold with add_bound *)
    let xvs = List.sort (fun (k,_) (k',_) -> compare k k') xvs in
    let xvs = List.rev_map snd xvs in
    Some xvs
  with Match_fail -> None
  end in
  return r
