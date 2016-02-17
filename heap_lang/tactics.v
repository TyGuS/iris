From heap_lang Require Export heap_lang.
From prelude Require Import fin_maps.
Import heap_lang.

(** The tactic [inv_step] performs inversion on hypotheses of the shape
[prim_step] and [head_step]. For hypotheses of the shape [prim_step] it will
decompose the evaluation context. The tactic will discharge
head-reductions starting from values, and simplifies hypothesis related
to conversions from and to values, and finite map operations. This tactic is
slightly ad-hoc and tuned for proving our lifting lemmas. *)
Ltac inv_step :=
  repeat match goal with
  | _ => progress simplify_map_equality' (* simplify memory stuff *)
  | H : to_val _ = Some _ |- _ => apply of_to_val in H
  | H : context [to_val (of_val _)] |- _ => rewrite to_of_val in H
  | H : prim_step _ _ _ _ _ |- _ => destruct H; subst
  | H : _ = fill ?K ?e |- _ =>
     destruct K as [|[]];
     simpl in H; first [subst e|discriminate H|injection H as H]
     (* ensure that we make progress for each subgoal *)
  | H : head_step ?e _ _ _ _, Hv : of_val ?v = fill ?K ?e |- _ =>
    apply values_head_stuck, (fill_not_val K) in H;
    by rewrite -Hv to_of_val in H (* maybe use a helper lemma here? *)
  | H : head_step ?e _ _ _ _ |- _ =>
     try (is_var e; fail 1); (* inversion yields many goals if e is a variable
     and can thus better be avoided. *)
     inversion H; subst; clear H
  end.

(** The tactic [reshape_expr e tac] decomposes the expression [e] into an
evaluation context [K] and a subexpression [e']. It calls the tactic [tac K e']
for each possible decomposition until [tac] succeeds. *)
Ltac reshape_val e tac :=
  let rec go e :=
  match e with
  | of_val ?v => v
  | Rec ?f ?x ?e => constr:(RecV f x e)
  | Lit ?l => constr:(LitV l)
  | Pair ?e1 ?e2 =>
    let v1 := reshape_val e1 in let v2 := reshape_val e2 in constr:(PairV v1 v2)
  | InjL ?e => let v := reshape_val e in constr:(InjLV v)
  | InjR ?e => let v := reshape_val e in constr:(InjRV v)
  | Loc ?l => constr:(LocV l)
  end in let v := go e in first [tac v | fail 2].

Ltac reshape_expr e tac :=
  let rec go K e :=
  match e with
  | _ => tac (reverse K) e
  | App ?e1 ?e2 => reshape_val e1 ltac:(fun v1 => go (AppRCtx v1 :: K) e2)
  | App ?e1 ?e2 => go (AppLCtx e2 :: K) e1
  | UnOp ?op ?e => go (UnOpCtx op :: K) e
  | BinOp ?op ?e1 ?e2 =>
     reshape_val e1 ltac:(fun v1 => go (BinOpRCtx op v1 :: K) e2)
  | BinOp ?op ?e1 ?e2 => go (BinOpLCtx op e2 :: K) e1
  | If ?e0 ?e1 ?e2 => go (IfCtx e1 e2 :: K) e0
  | Pair ?e1 ?e2 => reshape_val e1 ltac:(fun v1 => go (PairRCtx v1 :: K) e2)
  | Pair ?e1 ?e2 => go (PairLCtx e2 :: K) e1
  | Fst ?e => go (FstCtx :: K) e
  | Snd ?e => go (SndCtx :: K) e
  | InjL ?e => go (InjLCtx :: K) e
  | InjR ?e => go (InjRCtx :: K) e
  | Case ?e0 ?e1 ?e2 => go (CaseCtx e1 e2 :: K) e0
  | Alloc ?e => go (AllocCtx :: K) e
  | Load ?e => go (LoadCtx :: K) e
  | Store ?e1 ?e2 => reshape_val e1 ltac:(fun v1 => go (StoreRCtx v1 :: K) e2)
  | Store ?e1 ?e2 => go (StoreLCtx e2 :: K) e1
  | Cas ?e0 ?e1 ?e2 => reshape_val e0 ltac:(fun v0 => first
     [ reshape_val e1 ltac:(fun v1 => go (CasRCtx v0 v1 :: K) e2)
     | go (CasMCtx v0 e2 :: K) e1 ])
  | Cas ?e0 ?e1 ?e2 => go (CasLCtx e1 e2 :: K) e0
  end in go (@nil ectx_item) e.

(** The tactic [do_step tac] solves goals of the shape [reducible], [prim_step]
and [head_step] by performing a reduction step and uses [tac] to solve any
side-conditions generated by individual steps. In case of goals of the shape
[reducible] and [prim_step], it will try to decompose to expression on the LHS
into an evaluation context and head-redex. *)
Ltac do_step tac :=
  try match goal with |- language.reducible _ _ => eexists _, _, _ end;
  simpl;
  match goal with
  | |- prim_step ?e1 ?σ1 ?e2 ?σ2 ?ef =>
     reshape_expr e1 ltac:(fun K e1' =>
       eapply Ectx_step with K e1' _; [reflexivity|reflexivity|];
       first [apply alloc_fresh|econstructor];
       rewrite ?to_of_val; tac; fail)
  | |- head_step ?e1 ?σ1 ?e2 ?σ2 ?ef =>
     first [apply alloc_fresh|econstructor];
     rewrite ?to_of_val; tac; fail
  end.
