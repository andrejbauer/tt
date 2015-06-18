(** Conversion from sugared to desugared input syntax *)

let add_bound x bound = x :: bound

let rec mk_lambda ys ((c', loc) as c) =
  match ys with
  | [] -> c'
  | _ :: _ ->
    begin match c' with
      | Syntax.Lambda (ys', c) -> mk_lambda (ys @ ys') c
      | _ -> Syntax.Lambda (ys, c)
    end

let rec mk_prod ys ((t', loc) as t) =
  match ys with
  | [] -> t'
  | _ :: _ ->
    begin match t' with
      | Syntax.Prod (ys', t) -> mk_prod (ys @ ys') t
      | _ -> Syntax.Prod (ys, t)
    end

let mk_let ~loc w c' =
  match w with
  | [] -> c', loc
  | _ :: _ -> Syntax.Let (w, (c', loc)), loc

let rec comp primitive bound ((c',loc) as c) =
  (* When a computation [c] is desugared we hoist out a list of
     let-bindings [w]. NB: it is important that we first desugar
     all subexpressions of [c] so that we get the correct context
     with hoisted bindings, and only then we desugar the subcomputations
     of [c]. *)
  let w, c = match c' with

    | Input.Let (xcs, c2) ->
      let rec fold = function
        | [] -> []
        | (x,c) :: xcs ->
          if List.mem_assoc x xcs
          then
            Error.syntax ~loc "%t is bound more than once" (Name.print x)
          else
            let c = comp primitive bound c in
            let xcs = fold xcs in
            (x, c) :: xcs
      in
      let xcs = fold xcs in
      let bound = List.fold_left (fun bound (x,_) -> add_bound x bound) bound xcs in
      let c2 = comp primitive bound c2 in
      [], Syntax.Let (xcs, c2)

    | Input.Beta (e, c) ->
      let bound, w, e = expr primitive bound e in
      let c = comp primitive bound c in
        w, Syntax.Beta (e, c)

    | Input.Eta (e, c) ->
      let bound, w, e = expr primitive bound e in
      let c = comp primitive bound c in
        w, Syntax.Eta (e, c)

    | Input.Hint (e, c) ->
      let bound, w, e = expr primitive bound e in
      let c = comp primitive bound c in
        w, Syntax.Hint (e, c)

    | Input.Inhabit (e, c) ->
      let bound, w, e = expr primitive bound e in
      let c = comp primitive bound c in
        w, Syntax.Inhabit (e, c)

    | Input.Ascribe (c, t) ->
      let bound, w, t = expr primitive bound t in
      let c = comp primitive bound c in
      w, Syntax.Ascribe (c, t)

    | Input.Lambda (xs, c) ->
      let rec fold bound ys = function
        | [] ->
          let c = comp primitive bound c in
          mk_lambda ys c
        | (x, None) :: xs ->
          let bound = add_bound x bound
          and ys = ys @ [(x, None)] in
          fold bound ys xs
        | (x, Some t) :: xs ->
          let t = comp primitive bound t in
          let bound = add_bound x bound
          and ys = ys @ [(x, Some t)] in
          fold bound ys xs
      in
      [], fold bound [] xs

    | Input.Spine (e, cs) ->
      spine primitive bound e cs

    | Input.Prod (xs, c) ->
      let rec fold bound ys = function
        | [] ->
          let c = comp primitive bound c in
          mk_prod ys c
        | (x,t) :: xs ->
          begin
            match expr primitive bound t with
            | _, [], t ->
              let bound = add_bound x bound
              and ys = ys @ [(x,t)] in
              fold bound ys xs
            | bound, w, ((_,loc) as t) ->
              let c = fold (add_bound x bound) [] xs in
              let c = Syntax.Prod ([(x,t)], (c,loc)) in
              let c = mk_let ~loc:(snd t) w c in
              mk_prod ys c
          end
      in
      [], fold bound [] xs

    | Input.Eq (c1, c2) ->
      let c1 = comp primitive bound c1
      and c2 = comp primitive bound c2 in
      [], Syntax.Eq (c1, c2)

    | Input.Refl c ->
      let c = comp primitive bound c in
      [], Syntax.Refl c

    | Input.Bracket c ->
      let c = comp primitive bound c in
      [], Syntax.Bracket c

    | Input.Inhab ->
      [], Syntax.Inhab

    | (Input.Var _ | Input.Type) ->
      let _, w, e = expr primitive bound c in
      w, Syntax.Return e

  in
  mk_let ~loc w c

(* Desguar a spine. This function is a bit messy because we need to untangle
   to primitive operations. But it's worth doing to make users happy. *)
and spine primitive bound ((e',loc) as e) cs =
  (* Auxiliary function which splits a list into two parts with k
     elements in the first part. *)
  let rec split k lst =
    if k = 0 then
      [], lst
    else
      match lst with
        | [] -> Error.syntax ~loc "this primitive operation needs %d more arguments" k
        | x::lst -> let lst, lst' = split (k-1) lst in (x :: lst, lst')
  in
  (* First we calculate the head of the spine, and the remaining arguments. *)
  let (bound, w, e), cs =
    begin
      match e' with
      | Input.Var x when not (List.mem x bound) ->
        begin
          try
            let k = List.assoc x primitive in
            let cs', cs = split k cs in
              (* We make a primitive application from [x] and [cs'] *)
              primapp ~loc primitive bound x cs', cs
          with Not_found -> expr primitive bound e, cs
        end
      | _ -> expr primitive bound e, cs
    end in
  (* Process the remaining arguments. *)
  let cs = List.map (comp primitive bound) cs in
  w, Syntax.Spine (e, cs)

(* Make a primitive application as if it were in an expression position *)
and primapp ~loc primitive bound x cs =
  let cs = List.map (comp primitive bound) cs in
  let c = Syntax.PrimApp (x, cs), loc
  and y = Name.fresh Name.anonymous in
  let bound = add_bound y bound in
  bound, [(y, c)], (Syntax.Bound 0, loc)

(* Desugar an expression. It hoists out subcomputations appearing in the
   expression. *)
and expr primitive bound ((e', loc) as e) =
  match e' with
  | Input.Var x ->
    begin
      (* a bound variable always shadows a name *)
      match Name.index_of x bound with
      | None ->
        (* it is either a primitive operation of arity 0 or a name *)
        (* XXX soon the only option will be a primitive operation of arity 0 *)
        begin
          try
            let k = List.assoc x primitive in
            if k = 0 then primapp ~loc primitive bound x []
            else Error.syntax ~loc "this primitive operation needs %d more arguments" k
          with Not_found ->
            (* it is a name *)
            (* XXX soon we will remove names *)
            bound, [], (Syntax.Name x, loc)
        end
      | Some k -> bound, [], (Syntax.Bound k, loc)
    end

  | Input.Type ->
    bound, [], (Syntax.Type, loc)

  | (Input.Let _ | Input.Beta _ | Input.Eta _ | Input.Hint _ | Input.Inhabit _ |
     Input.Bracket _ | Input.Inhab | Input.Ascribe _ | Input.Lambda _ |
     Input.Spine _ | Input.Prod _ | Input.Eq _ | Input.Refl _) ->
    let x = Name.fresh Name.anonymous
    and c = comp primitive bound e in
    let bound = add_bound x bound in
    bound, [(x,c)], (Syntax.Bound 0, loc)

let toplevel primitive bound (d', loc) =
  let d' = match d' with

    | Input.Primitive (x, yts, u) ->
      let rec fold bound yts' = function
        | [] ->
          let u = comp primitive bound u in
          let yts' = List.rev yts' in
          (yts', u)
        | (y, reducing, t) :: yts ->
          let t = comp primitive bound t in
          let bound = add_bound y bound
          and yts' = (y, reducing, t) :: yts' in
          fold bound yts' yts
      in
      let yts, u = fold bound [] yts in
      Syntax.Primitive (x, yts, u)

    | Input.TopLet (x, c) ->
      let c = comp primitive bound c in
      Syntax.TopLet (x, c)

    | Input.TopCheck c ->
      let c = comp primitive bound c in
      Syntax.TopCheck c

    | Input.TopBeta c ->
      let c = comp primitive bound c in
      Syntax.TopBeta c

    | Input.TopEta c ->
      let c = comp primitive bound c in
      Syntax.TopEta c

    | Input.TopHint c ->
      let c = comp primitive bound c in
      Syntax.TopHint c

    | Input.TopInhabit c ->
      let c = comp primitive bound c in
      Syntax.TopInhabit c

    | Input.Quit -> Syntax.Quit

    | Input.Help -> Syntax.Help

    | Input.Verbosity n -> Syntax.Verbosity n

    | Input.Include fs -> Syntax.Include fs

    | Input.Context -> Syntax.Context

  in
  d', loc