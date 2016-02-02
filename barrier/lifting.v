Require Import prelude.gmap iris.lifting.
Require Export iris.weakestpre barrier.heap_lang_tactics.
Import uPred.
Import heap_lang.
Local Hint Extern 0 (language.reducible _ _) => do_step ltac:(eauto 2).

Section lifting.
Context {Σ : iFunctor}.
Implicit Types P : iProp heap_lang Σ.
Implicit Types Q : val → iProp heap_lang Σ.
Implicit Types K : ectx.

(** Bind. *)
Lemma wp_bind {E e} K Q :
  wp E e (λ v, wp E (fill K (of_val v)) Q) ⊑ wp E (fill K e) Q.
Proof. apply wp_bind. Qed.

(** Base axioms for core primitives of the language: Stateful reductions. *)
Lemma wp_alloc_pst E σ e v Q :
  to_val e = Some v →
  (ownP σ ★ ▷ (∀ l, ■(σ !! l = None) ∧ ownP (<[l:=v]>σ) -★ Q (LocV l)))
       ⊑ wp E (Alloc e) Q.
Proof.
  intros; set (φ e' σ' ef := ∃ l, e' = Loc l ∧ σ' = <[l:=v]>σ ∧ σ !! l = None
                                ∧ ef = (None : option expr)).
  rewrite -(wp_lift_step E E φ _ _  σ) // /φ; last (by intros; inv_step; eauto); [].
  rewrite -pvs_intro. apply sep_mono, later_mono; first done.
  apply forall_intro=>e2; apply forall_intro=>σ2; apply forall_intro=>ef.
  apply wand_intro_l.
  rewrite -pvs_intro always_and_sep_l' -associative -always_and_sep_l'.
  apply const_elim_l=>-[l [-> [-> [? ->]]]].
  rewrite right_id (forall_elim l) const_equiv //.
  by rewrite left_id wand_elim_r -wp_value'.
Qed.

Lemma wp_load_pst E σ l v Q :
  σ !! l = Some v →
  (ownP σ ★ ▷ (ownP σ -★ Q v)) ⊑ wp E (Load (Loc l)) Q.
Proof.
  intros; rewrite -(wp_lift_atomic_det_step σ v σ) //;
    last (by intros; inv_step; eauto).
Qed.

Lemma wp_store_pst E σ l e v v' Q :
  to_val e = Some v → σ !! l = Some v' →
  (ownP σ ★ ▷ (ownP (<[l:=v]>σ) -★ Q LitUnitV)) ⊑ wp E (Store (Loc l) e) Q.
Proof.
  intros.
  rewrite -(wp_lift_atomic_det_step σ LitUnitV (<[l:=v]>σ)) //;
    last by intros; inv_step; eauto.
Qed.

Lemma wp_cas_fail_pst E σ l e1 v1 e2 v2 v' Q :
  to_val e1 = Some v1 → to_val e2 = Some v2 → σ !! l = Some v' → v' ≠ v1 →
  (ownP σ ★ ▷ (ownP σ -★ Q LitFalseV)) ⊑ wp E (Cas (Loc l) e1 e2) Q.
Proof.
  intros; rewrite -(wp_lift_atomic_det_step σ LitFalseV σ) //;
    last by intros; inv_step; eauto.
Qed.

Lemma wp_cas_suc_pst E σ l e1 v1 e2 v2 Q :
  to_val e1 = Some v1 → to_val e2 = Some v2 → σ !! l = Some v1 →
  (ownP σ ★ ▷ (ownP (<[l:=v2]>σ) -★ Q LitTrueV)) ⊑ wp E (Cas (Loc l) e1 e2) Q.
Proof.
  intros.
  rewrite -(wp_lift_atomic_det_step σ LitTrueV (<[l:=v2]>σ)) //;
    last by intros; inv_step; eauto.
Qed.

(** Base axioms for core primitives of the language: Stateless reductions *)
Lemma wp_fork E e :
  ▷ wp (Σ:=Σ) coPset_all e (λ _, True) ⊑ wp E (Fork e) (λ v, ■(v = LitUnitV)).
Proof.
  rewrite -(wp_lift_pure_step E (λ e' ef, e' = LitUnit ∧ ef = Some e)) //=;
    last by intros; inv_step; eauto.
  apply later_mono, forall_intro=>e2; apply forall_intro=>ef.
  apply impl_intro_l, const_elim_l=>-[-> ->] /=.
  apply sep_intro_True_l; last done.
  by rewrite -wp_value' //; apply const_intro.
Qed.

Lemma wp_rec E ef e v Q :
  to_val e = Some v →
  ▷ wp E ef.[Rec ef, e /] Q ⊑ wp E (App (Rec ef) e) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (App _ _) ef.[Rec ef, e /]) //=;
    last by intros; inv_step; eauto.
Qed.

Lemma wp_plus E n1 n2 Q :
  ▷ Q (LitNatV (n1 + n2)) ⊑ wp E (Plus (LitNat n1) (LitNat n2)) Q.
Proof.
  rewrite -(wp_lift_pure_det_step (Plus _ _) (LitNat (n1 + n2))) //=;
    last by intros; inv_step; eauto.
  by rewrite -wp_value'.
Qed.

Lemma wp_le_true E n1 n2 Q :
  n1 ≤ n2 →
  ▷ Q LitTrueV ⊑ wp E (Le (LitNat n1) (LitNat n2)) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (Le _ _) LitTrue) //=;
    last by intros; inv_step; eauto with lia.
  by rewrite -wp_value'.
Qed.

Lemma wp_le_false E n1 n2 Q :
  n1 > n2 →
  ▷ Q LitFalseV ⊑ wp E (Le (LitNat n1) (LitNat n2)) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (Le _ _) LitFalse) //=;
    last by intros; inv_step; eauto with lia.
  by rewrite -wp_value'.
Qed.

Lemma wp_fst E e1 v1 e2 v2 Q :
  to_val e1 = Some v1 → to_val e2 = Some v2 →
  ▷Q v1 ⊑ wp E (Fst (Pair e1 e2)) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (Fst _) e1) //=;
    last by intros; inv_step; eauto.
  by rewrite -wp_value'.
Qed.

Lemma wp_snd E e1 v1 e2 v2 Q :
  to_val e1 = Some v1 → to_val e2 = Some v2 →
  ▷ Q v2 ⊑ wp E (Snd (Pair e1 e2)) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (Snd _) e2) //=;
    last by intros; inv_step; eauto.
  by rewrite -wp_value'.
Qed.

Lemma wp_case_inl E e0 v0 e1 e2 Q :
  to_val e0 = Some v0 →
  ▷ wp E e1.[e0/] Q ⊑ wp E (Case (InjL e0) e1 e2) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (Case _ _ _) e1.[e0/]) //=;
    last by intros; inv_step; eauto.
Qed.

Lemma wp_case_inr E e0 v0 e1 e2 Q :
  to_val e0 = Some v0 →
  ▷ wp E e2.[e0/] Q ⊑ wp E (Case (InjR e0) e1 e2) Q.
Proof.
  intros; rewrite -(wp_lift_pure_det_step (Case _ _ _) e2.[e0/]) //=;
    last by intros; inv_step; eauto.
Qed.

(** Some derived stateless axioms *)
Lemma wp_le E n1 n2 P Q :
  (n1 ≤ n2 → P ⊑ ▷ Q LitTrueV) →
  (n1 > n2 → P ⊑ ▷ Q LitFalseV) →
  P ⊑ wp E (Le (LitNat n1) (LitNat n2)) Q.
Proof.
  intros; destruct (decide (n1 ≤ n2)).
  * rewrite -wp_le_true; auto.
  * rewrite -wp_le_false; auto with lia.
Qed.

End lifting.
