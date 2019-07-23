(** Equality checking and coercions *)

let return = Runtime.return
let (>>=) = Runtime.bind


(** Compare two terms *)
let equal_term ~loc sgn e1 e2 =
  match Nucleus.form_alpha_equal_term sgn e1 e2 with
    | Some _ as eq -> return eq
    | None ->
      Reflect.operation_equal_term ~loc e1 e2 >>=
        begin function
          | None -> return None
          | Some eq ->
             let (Nucleus.Stump_EqTerm (_asmp, e1', e2', _)) = Nucleus.invert_eq_term eq in
             begin
               match Nucleus.alpha_equal_term e1 e1' && Nucleus.alpha_equal_term e2 e2' with
               | false -> Runtime.(error ~loc (InvalidEqualTerm (e1, e2)))
               | true -> return (Some eq)
             end
        end

(* Compare two types *)
let equal_type ~loc t1 t2 =
  match Nucleus.form_alpha_equal_type t1 t2 with
    | Some _ as eq -> return eq
    | None ->
      Reflect.operation_equal_type ~loc t1 t2 >>= function
      | None -> return None

      | Some eq ->
         let (Nucleus.Stump_EqType (_asmp, t1', t2')) = Nucleus.invert_eq_type eq in
         if Nucleus.alpha_equal_type t1 t1' && Nucleus.alpha_equal_type t2 t2' then
           return (Some eq)
         else
           Runtime.(error ~loc (InvalidEqualType (t1, t2)))

let coerce ~loc sgn jdg bdry =
  if Nucleus.check_judgement_boundary sgn jdg bdry then
    return (Some jdg)
  else
    Reflect.operation_coerce ~loc jdg bdry >>= function
    | None -> return None

    | Some jdg ->
       if Nucleus.check_judgement_boundary sgn jdg bdry then
         return (Some jdg)
       else
         Runtime.(error ~loc (InvalidCoerce (jdg, bdry)))
