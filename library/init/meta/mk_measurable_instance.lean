/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura

Helper tactic for constructing measurable instance.
-/
prelude
import init.meta.rec_util init.combinator
import init.meta.constructor_tactic

namespace tactic
open expr environment list

/- Retrieve the name of the type we are building a measurable instance for. -/
private meta_definition get_measurable_type_name : tactic name :=
do {
  (app (const n _) t) ← target >>= whnf | failed,
  when (n ≠ `measurable) failed,
  (const I _) ← return (get_app_fn t) | failed,
  return I }
<|>
fail "mk_measurable_instance tactic failed, target type is expected to be of the form (measurable ...)"

/- Try to synthesize constructor argument using type class resolution -/
private meta_definition mk_measurable_instance_for (a : expr) (use_default : bool) : tactic expr :=
do t    ← infer_type a,
   do {
     m    ← mk_app `measurable [t],
     inst ← mk_instance m,
     mk_app `size_of [t, inst, a] }
   <|>
   if use_default = tt
   then return (const `nat.zero [])
   else do
     f ← pp t,
     fail (to_fmt "mk_measurable_instance failed, failed to generate instance for" ++ format.nest 2 (format.line ++ f))

private meta_definition mk_sizes_of : bool → name → name → list name → nat → tactic (list expr)
| _           _      _      []              num_rec := return []
| use_default I_name F_name (fname::fnames) num_rec := do
  field ← get_local fname,
  rec   ← is_type_app_of field I_name,
  sz    ← if rec = tt then mk_brec_on_rec_value F_name num_rec else mk_measurable_instance_for field use_default,
  szs   ← mk_sizes_of use_default I_name F_name fnames (if rec = tt then num_rec + 1 else num_rec),
  return (sz :: szs)

private meta_definition mk_sum : list expr → expr
| []      := app (const `nat.succ []) (const `nat.zero [])
| (e::es) := app (app (const `nat.add []) e) (mk_sum es)

private meta_definition measurable_case (use_default : bool) (I_name F_name : name) (field_names : list name) : tactic unit :=
do szs ← mk_sizes_of use_default I_name F_name field_names 0,
   exact (mk_sum szs)

private meta_definition for_each_measurable_goal : bool → name → name → list (list name) → tactic unit
| d I_name F_name [] := now <|> fail "mk_measurable_instance failed, unexpected number of cases"
| d I_name F_name (ns::nss) := do
  solve1 (measurable_case d I_name F_name ns),
  for_each_measurable_goal d I_name F_name nss

meta_definition mk_measurable_instance_core (use_default : bool) : tactic unit :=
do I_name ← get_measurable_type_name,
   constructor,
   env ← get_env,
   v_name : name ← return `_v,
   F_name : name ← return `_F,
   -- Use brec_on if type is recursive.
   -- We store the functional in the variable F.
   if (is_recursive env I_name = tt)
   then intro `_v >>= (λ x, induction_core semireducible x (I_name <.> "brec_on") [v_name, F_name])
   else intro v_name >> return (),
   arg_names : list (list name) ← mk_constructors_arg_names I_name `_p,
   get_local v_name >>= λ v, cases_using v (join arg_names),
   for_each_measurable_goal use_default I_name F_name arg_names


meta_definition mk_measurable_instance : tactic unit :=
mk_measurable_instance_core ff

end tactic