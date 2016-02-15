From prelude Require Export sets.
From algebra Require Export cmra.
From algebra Require Import dra.
Local Arguments valid _ _ !_ /.
Local Arguments op _ _ !_ !_ /.
Local Arguments unit _ _ !_ /.

Module sts.

Record Sts := {
  state : Type;
  token : Type;
  trans : relation state;
  tok   : state → set token;
}.

(* The type of bounds we can give to the state of an STS. This is the type
   that we equip with an RA structure. *)
Inductive bound (sts : Sts) :=
  | bound_auth : state sts → set (token sts) → bound sts
  | bound_frag : set (state sts) → set (token sts )→ bound sts.
Arguments bound_auth {_} _ _.
Arguments bound_frag {_} _ _.

Section sts_core.
Context (sts : Sts).
Infix "≼" := dra_included.

Notation state := (state sts).
Notation token := (token sts).
Notation trans := (trans sts).
Notation tok := (tok sts).

Inductive equiv : Equiv (bound sts) :=
  | auth_equiv s T1 T2 : T1 ≡ T2 → bound_auth s T1 ≡ bound_auth s T2
  | frag_equiv S1 S2 T1 T2 : T1 ≡ T2 → S1 ≡ S2 →
                             bound_frag S1 T1 ≡ bound_frag S2 T2.
Global Existing Instance equiv.
Inductive step : relation (state * set token) :=
  | Step s1 s2 T1 T2 :
     trans s1 s2 → tok s1 ∩ T1 ≡ ∅ → tok s2 ∩ T2 ≡ ∅ →
     tok s1 ∪ T1 ≡ tok s2 ∪ T2 → step (s1,T1) (s2,T2).
Hint Resolve Step.
Inductive frame_step (T : set token) (s1 s2 : state) : Prop :=
  | Frame_step T1 T2 :
     T1 ∩ (tok s1 ∪ T) ≡ ∅ → step (s1,T1) (s2,T2) → frame_step T s1 s2.
Hint Resolve Frame_step.
Record closed (S : set state) (T : set token) : Prop := Closed {
  closed_ne : S ≢ ∅;
  closed_disjoint s : s ∈ S → tok s ∩ T ≡ ∅;
  closed_step s1 s2 : s1 ∈ S → frame_step T s1 s2 → s2 ∈ S
}.
Lemma closed_steps S T s1 s2 :
  closed S T → s1 ∈ S → rtc (frame_step T) s1 s2 → s2 ∈ S.
Proof. induction 3; eauto using closed_step. Qed.
Global Instance valid : Valid (bound sts) := λ x,
  match x with
  | bound_auth s T => tok s ∩ T ≡ ∅ | bound_frag S' T => closed S' T
  end.
Definition up (s : state) (T : set token) : set state :=
  mkSet (rtc (frame_step T) s).
Definition up_set (S : set state) (T : set token) : set state
  := S ≫= λ s, up s T.
Global Instance unit : Unit (bound sts) := λ x,
  match x with
  | bound_frag S' _ => bound_frag (up_set S' ∅ ) ∅
  | bound_auth s _  => bound_frag (up s ∅) ∅
  end.
Inductive disjoint : Disjoint (bound sts) :=
  | frag_frag_disjoint S1 S2 T1 T2 :
     S1 ∩ S2 ≢ ∅ → T1 ∩ T2 ≡ ∅ → bound_frag S1 T1 ⊥ bound_frag S2 T2
  | auth_frag_disjoint s S T1 T2 : s ∈ S → T1 ∩ T2 ≡ ∅ →
                                   bound_auth s T1 ⊥ bound_frag S T2
  | frag_auth_disjoint s S T1 T2 : s ∈ S → T1 ∩ T2 ≡ ∅ →
                                   bound_frag S T1 ⊥ bound_auth s T2.
Global Existing Instance disjoint.
Global Instance op : Op (bound sts) := λ x1 x2,
  match x1, x2 with
  | bound_frag S1 T1, bound_frag S2 T2 => bound_frag (S1 ∩ S2) (T1 ∪ T2)
  | bound_auth s T1, bound_frag _ T2 => bound_auth s (T1 ∪ T2)
  | bound_frag _ T1, bound_auth s T2 => bound_auth s (T1 ∪ T2)
  | bound_auth s T1, bound_auth _ T2 =>
    bound_auth s (T1 ∪ T2)(* never happens *)
  end.
Global Instance minus : Minus (bound sts) := λ x1 x2,
  match x1, x2 with
  | bound_frag S1 T1, bound_frag S2 T2 => bound_frag
                                            (up_set S1 (T1 ∖ T2)) (T1 ∖ T2)
  | bound_auth s T1, bound_frag _ T2 => bound_auth s (T1 ∖ T2)
  | bound_frag _ T2, bound_auth s T1 =>
    bound_auth s (T1 ∖ T2) (* never happens *)
  | bound_auth s T1, bound_auth _ T2 => bound_frag (up s (T1 ∖ T2)) (T1 ∖ T2)
  end.

Hint Extern 10 (base.equiv (A:=set _) _ _) => solve_elem_of : sts.
Hint Extern 10 (¬(base.equiv (A:=set _) _ _)) => solve_elem_of : sts.
Hint Extern 10 (_ ∈ _) => solve_elem_of : sts.
Hint Extern 10 (_ ⊆ _) => solve_elem_of : sts.
Instance: Equivalence ((≡) : relation (bound sts)).
Proof.
  split.
  * by intros []; constructor.
  * by destruct 1; constructor.
  * destruct 1; inversion_clear 1; constructor; etransitivity; eauto.
Qed.
Instance framestep_proper : Proper ((≡) ==> (=) ==> (=) ==> impl) frame_step.
Proof. intros ?? HT ?? <- ?? <-; destruct 1; econstructor; eauto with sts. Qed.
Instance closed_proper' : Proper ((≡) ==> (≡) ==> impl) closed.
Proof.
  intros ?? HT ?? HS; destruct 1;
    constructor; intros until 0; rewrite -?HS -?HT; eauto.
Qed.
Instance closed_proper : Proper ((≡) ==> (≡) ==> iff) closed.
Proof. by split; apply closed_proper'. Qed.
Lemma closed_op T1 T2 S1 S2 :
  closed S1 T1 → closed S2 T2 →
  T1 ∩ T2 ≡ ∅ → S1 ∩ S2 ≢ ∅ → closed (S1 ∩ S2) (T1 ∪ T2).
Proof.
  intros [_ ? Hstep1] [_ ? Hstep2] ?; split; [done|solve_elem_of|].
  intros s3 s4; rewrite !elem_of_intersection; intros [??] [T3 T4 ?]; split.
  * apply Hstep1 with s3, Frame_step with T3 T4; auto with sts.
  * apply Hstep2 with s3, Frame_step with T3 T4; auto with sts.
Qed.
Instance up_preserving : Proper ((=) ==> flip (⊆) ==> (⊆)) up.
Proof.
  intros s ? <- T T' HT ; apply elem_of_subseteq.
  induction 1 as [|s1 s2 s3 [T1 T2]]; [constructor|].
  eapply rtc_l; [eapply Frame_step with T1 T2|]; eauto with sts.
Qed.
Instance up_proper : Proper ((=) ==> (≡) ==> (≡)) up.
Proof. by intros ??? ?? [??]; split; apply up_preserving. Qed.
Instance up_set_preserving : Proper ((⊆) ==> flip (⊆) ==> (⊆)) up_set.
Proof.
  intros S1 S2 HS T1 T2 HT. rewrite /up_set.
  f_equiv; last done. move =>s1 s2 Hs. simpl in HT. by apply up_preserving.
Qed.
Instance up_set_proper : Proper ((≡) ==> (≡) ==> (≡)) up_set.
Proof.
    by intros ?? EQ1 ?? EQ2; split; apply up_set_preserving; rewrite ?EQ1 ?EQ2.
Qed.
Lemma elem_of_up s T : s ∈ up s T.
Proof. constructor. Qed.
Lemma subseteq_up_set S T : S ⊆ up_set S T.
Proof. intros s ?; apply elem_of_bind; eauto using elem_of_up. Qed.
Lemma up_up_set s T : up s T ≡ up_set {[ s ]} T.
Proof. by rewrite /up_set collection_bind_singleton. Qed.
Lemma closed_up_set S T :
  (∀ s, s ∈ S → tok s ∩ T ≡ ∅) → S ≢ ∅ → closed (up_set S T) T.
Proof.
  intros HS Hne; unfold up_set; split.
  * assert (∀ s, s ∈ up s T) by eauto using elem_of_up. solve_elem_of.
  * intros s; rewrite !elem_of_bind; intros (s'&Hstep&Hs').
    specialize (HS s' Hs'); clear Hs' Hne S.
    induction Hstep as [s|s1 s2 s3 [T1 T2 ? Hstep] ? IH]; auto.
    inversion_clear Hstep; apply IH; clear IH; auto with sts.
  * intros s1 s2; rewrite !elem_of_bind; intros (s&?&?) ?; exists s.
    split; [eapply rtc_r|]; eauto.
Qed.
Lemma closed_up_set_empty S : S ≢ ∅ → closed (up_set S ∅) ∅.
Proof. eauto using closed_up_set with sts. Qed.
Lemma closed_up s T : tok s ∩ T ≡ ∅ → closed (up s T) T.
Proof.
  intros; rewrite -(collection_bind_singleton (λ s, up s T) s).
  apply closed_up_set; solve_elem_of.
Qed.
Lemma closed_up_empty s : closed (up s ∅) ∅.
Proof. eauto using closed_up with sts. Qed.
Lemma up_closed S T : closed S T → up_set S T ≡ S.
Proof.
  intros; split; auto using subseteq_up_set; intros s.
  unfold up_set; rewrite elem_of_bind; intros (s'&Hstep&?).
  induction Hstep; eauto using closed_step.
Qed.
Global Instance dra : DRA (bound sts).
Proof.
  split.
  * apply _.
  * by do 2 destruct 1; constructor; setoid_subst.
  * by destruct 1; constructor; setoid_subst.
  * by intros ? [|]; destruct 1; inversion_clear 1; constructor; setoid_subst.
  * by do 2 destruct 1; constructor; setoid_subst.
  * assert (∀ T T' S s,
      closed S T → s ∈ S → tok s ∩ T' ≡ ∅ → tok s ∩ (T ∪ T') ≡ ∅).
    { intros S T T' s [??]; solve_elem_of. }
    destruct 3; simpl in *; auto using closed_op with sts.
  * intros []; simpl; eauto using closed_up, closed_up_set, closed_ne with sts.
  * intros ???? (z&Hy&?&Hxz); destruct Hxz; inversion Hy;clear Hy; setoid_subst;
      rewrite ?disjoint_union_difference; auto using closed_up with sts.
    eapply closed_up_set; eauto 2 using closed_disjoint with sts.
  * intros [] [] []; constructor; rewrite ?assoc; auto with sts.
  * destruct 4; inversion_clear 1; constructor; auto with sts.
  * destruct 4; inversion_clear 1; constructor; auto with sts.
  * destruct 1; constructor; auto with sts.
  * destruct 3; constructor; auto with sts.
  * intros [|S T]; constructor; auto using elem_of_up with sts.
    assert (S ⊆ up_set S ∅ ∧ S ≢ ∅) by eauto using subseteq_up_set, closed_ne.
    solve_elem_of.
  * intros [|S T]; constructor; auto with sts.
    assert (S ⊆ up_set S ∅); auto using subseteq_up_set with sts.
  * intros [s T|S T]; constructor; auto with sts.
    + rewrite (up_closed (up _ _)); auto using closed_up with sts.
    + rewrite (up_closed (up_set _ _));
        eauto using closed_up_set, closed_ne with sts.
  * intros x y ?? (z&Hy&?&Hxz); exists (unit (x ⋅ y)); split_ands.
    + destruct Hxz;inversion_clear Hy;constructor;unfold up_set; solve_elem_of.
    + destruct Hxz; inversion_clear Hy; simpl;
        auto using closed_up_set_empty, closed_up_empty with sts.
    + destruct Hxz; inversion_clear Hy; constructor;
        repeat match goal with
        | |- context [ up_set ?S ?T ] =>
           unless (S ⊆ up_set S T) by done; pose proof (subseteq_up_set S T)
        | |- context [ up ?s ?T ] =>
           unless (s ∈ up s T) by done; pose proof (elem_of_up s T)
        end; auto with sts.
  * intros x y ?? (z&Hy&_&Hxz); destruct Hxz; inversion_clear Hy; constructor;
      repeat match goal with
      | |- context [ up_set ?S ?T ] =>
         unless (S ⊆ up_set S T) by done; pose proof (subseteq_up_set S T)
      | |- context [ up ?s ?T ] =>
           unless (s ∈ up s T) by done; pose proof (elem_of_up s T)
      end; auto with sts.
  * intros x y ?? (z&Hy&?&Hxz); destruct Hxz as [S1 S2 T1 T2| |];
      inversion Hy; clear Hy; constructor; setoid_subst;
      rewrite ?disjoint_union_difference; auto.
    split; [|apply intersection_greatest; auto using subseteq_up_set with sts].
    apply intersection_greatest; [auto with sts|].
    intros s2; rewrite elem_of_intersection.
    unfold up_set; rewrite elem_of_bind; intros (?&s1&?&?&?).
    apply closed_steps with T2 s1; auto with sts.
Qed.
Lemma step_closed s1 s2 T1 T2 S Tf :
  step (s1,T1) (s2,T2) → closed S Tf → s1 ∈ S → T1 ∩ Tf ≡ ∅ →
  s2 ∈ S ∧ T2 ∩ Tf ≡ ∅ ∧ tok s2 ∩ T2 ≡ ∅.
Proof.
  inversion_clear 1 as [???? HR Hs1 Hs2]; intros [?? Hstep]??; split_ands; auto.
  * eapply Hstep with s1, Frame_step with T1 T2; auto with sts.
  * solve_elem_of -Hstep Hs1 Hs2.
Qed.
End sts_core.

Section stsRA.
Context (sts : Sts).

Canonical Structure RA := validityRA (bound sts).
Definition auth (s : state sts) (T : set (token sts)) : RA :=
  to_validity (bound_auth s T).
Definition frag (S : set (state sts)) (T : set (token sts)) : RA :=
  to_validity (bound_frag S T).

Lemma update_auth s1 s2 T1 T2 :
  step sts (s1,T1) (s2,T2) → auth s1 T1 ~~> auth s2 T2.
Proof.
  intros ?; apply validity_update; inversion 3 as [|? S ? Tf|]; subst.
  destruct (step_closed sts s1 s2 T1 T2 S Tf) as (?&?&?); auto.
  repeat (done || constructor).
Qed.

Lemma sts_update_frag S1 S2 (T : set (token sts)) :
  S1 ⊆ S2 → closed sts S2 T →
  frag S1 T ~~> frag S2 T.
Proof.
  move=>HS Hcl. eapply validity_update; inversion 3 as [|? S ? Tf|]; subst.
  - split; first done. constructor; last done. solve_elem_of.
  - split; first done. constructor; solve_elem_of.
Qed.

Lemma frag_included S1 S2 T1 T2 :
  closed sts S2 T2 →
  frag S1 T1 ≼ frag S2 T2 ↔ 
  (closed sts S1 T1 ∧ ∃ Tf, T2 ≡ T1 ∪ Tf ∧ T1 ∩ Tf ≡ ∅ ∧
                            S2 ≡ (S1 ∩ up_set sts S2 Tf)).
Proof.
  move=>Hcl2. split.
  - intros [xf EQ]. destruct xf as [xf vf Hvf]. destruct xf as [Sf Tf|Sf Tf].
    { exfalso. inversion_clear EQ as [Hv EQ']. apply EQ' in Hcl2. simpl in Hcl2.
      inversion Hcl2. }
    inversion_clear EQ as [Hv EQ'].
    move:(EQ' Hcl2)=>{EQ'} EQ. inversion_clear EQ as [|? ? ? ? HT HS].
    destruct Hv as [Hv _]. move:(Hv Hcl2)=>{Hv} [/= Hcl1  [Hclf Hdisj]].
    apply Hvf in Hclf. simpl in Hclf. clear Hvf.
    inversion_clear Hdisj. split; last (exists Tf; split_ands); [done..|].
    apply (anti_symm (⊆)).
    + move=>s HS2. apply elem_of_intersection. split; first by apply HS.
      by apply sts.subseteq_up_set.
    + move=>s /elem_of_intersection [HS1 Hscl]. apply HS. split; first done.
      destruct Hscl as [s' [Hsup Hs']].
      eapply sts.closed_steps; last (hnf in Hsup; eexact Hsup); first done.
      solve_elem_of +HS Hs'.
  - intros (Hcl1 & Tf & Htk & Hf & Hs).
    exists (frag (up_set sts S2 Tf) Tf).
    split; first split; simpl;[|done|].
    + intros _. split_ands; first done.
      * apply sts.closed_up_set; last by eapply sts.closed_ne.
        move=>s Hs2. move:(closed_disjoint sts _ _ Hcl2 _ Hs2).
        solve_elem_of +Htk.
      * constructor; last done. rewrite -Hs. by eapply sts.closed_ne.
    + intros _. constructor; [ solve_elem_of +Htk | done].
Qed.

Lemma frag_included' S1 S2 T :
  closed sts S2 T → closed sts S1 T →
  S2 ≡ (S1 ∩ sts.up_set sts S2 ∅) →
  frag S1 T ≼ frag S2 T.
Proof.
  intros. apply frag_included; first done.
  split; first done. exists ∅. split_ands; done || solve_elem_of+.
Qed.

End stsRA.

End sts.
