From iris.algebra Require Import upred.
From iris.proofmode Require Import tactics.

(** This proves that we need the ▷ in a "Saved Proposition" construction with
name-dependend allocation. *)
Section savedprop.
  Context (M : ucmraT).
  Notation iProp := (uPred M).
  Notation "¬ P" := (□ (P → False))%I : uPred_scope.
  Implicit Types P : iProp.

  (* Saved Propositions and view shifts. *)
  Context (sprop : Type) (saved : sprop → iProp → iProp).
  Hypothesis sprop_persistent : ∀ i P, PersistentP (saved i P).
  Hypothesis sprop_alloc_dep :
    ∀ (P : sprop → iProp), True =r=> (∃ i, saved i (P i)).
  Hypothesis sprop_agree : ∀ i P Q, saved i P ∧ saved i Q ⊢ P ↔ Q.

  (* Self-contradicting assertions are inconsistent *)
  Lemma no_self_contradiction P `{!PersistentP P} : □ (P ↔ ¬ P) ⊢ False.
  Proof.
    iIntros "#[H1 H2]".
    iAssert P as "#HP".
    { iApply "H2". iIntros "!# #HP". by iApply ("H1" with "[#]"). }
    by iApply ("H1" with "[#]").
  Qed.

  (* "Assertion with name [i]" is equivalent to any assertion P s.t. [saved i P] *)
  Definition A (i : sprop) : iProp := ∃ P, saved i P ★ □ P.
  Lemma saved_is_A i P `{!PersistentP P} : saved i P ⊢ □ (A i ↔ P).
  Proof.
    iIntros "#HS !#". iSplit.
    - iDestruct 1 as (Q) "[#HSQ HQ]".
      iApply (sprop_agree i P Q with "[]"); eauto.
    - iIntros "#HP". iExists P. by iSplit.
  Qed.

  (* Define [Q i] to be "negated assertion with name [i]". Show that this
     implies that assertion with name [i] is equivalent to its own negation. *)
  Definition Q i := saved i (¬ A i).
  Lemma Q_self_contradiction i : Q i ⊢ □ (A i ↔ ¬ A i).
  Proof. iIntros "#HQ !#". by iApply (saved_is_A i (¬A i)). Qed.

  (* We can obtain such a [Q i]. *)
  Lemma make_Q : True =r=> ∃ i, Q i.
  Proof. apply sprop_alloc_dep. Qed.

  (* Put together all the pieces to derive a contradiction. *)
  Lemma rvs_false : (True : uPred M) =r=> False.
  Proof.
    rewrite make_Q. apply uPred.rvs_mono. iDestruct 1 as (i) "HQ".
    iApply (no_self_contradiction (A i)). by iApply Q_self_contradiction.
  Qed.

  Lemma contradiction : False.
  Proof.
    apply (@uPred.adequacy M False 1); simpl.
    rewrite -uPred.later_intro. apply rvs_false.
  Qed.
End savedprop.

(** This proves that we need the ▷ when opening invariants. *)
(** We fork in [uPred M] for any M, but the proof would work in any BI. *)
Section inv.
  Context (M : ucmraT).
  Notation iProp := (uPred M).
  Notation "¬ P" := (□ (P → False))%I : uPred_scope.
  Implicit Types P : iProp.

  (** Assumptions *)
  (* We have view shifts (two classes: empty/full mask) *)
  Context (pvs0 pvs1 : iProp → iProp).

  Hypothesis pvs0_intro : forall P, P ⊢ pvs0 P.

  Hypothesis pvs0_mono : forall P Q, (P ⊢ Q) → pvs0 P ⊢ pvs0 Q.
  Hypothesis pvs0_pvs0 : forall P, pvs0 (pvs0 P) ⊢ pvs0 P.
  Hypothesis pvs0_frame_l : forall P Q, P ★ pvs0 Q ⊢ pvs0 (P ★ Q).

  Hypothesis pvs1_mono : forall P Q, (P ⊢ Q) → pvs1 P ⊢ pvs1 Q.
  Hypothesis pvs1_pvs1 : forall P, pvs1 (pvs1 P) ⊢ pvs1 P.
  Hypothesis pvs1_frame_l : forall P Q, P ★ pvs1 Q ⊢ pvs1 (P ★ Q).

  Hypothesis pvs0_pvs1 : forall P, pvs0 P ⊢ pvs1 P.

  (* We have invariants *)
  Context (name : Type) (inv : name → iProp → iProp).
  Hypothesis inv_persistent : forall i P, PersistentP (inv i P).
  Hypothesis inv_alloc :
    forall (P : iProp), P ⊢ pvs1 (∃ i, inv i P).
  Hypothesis inv_open :
    forall i P Q R, (P ★ Q ⊢ pvs0 (P ★ R)) → (inv i P ★ Q ⊢ pvs1 R).

  (* We have tokens for a little "three-state STS": [fresh] -> [start n] ->
     [finish n].  The [auth_*] tokens are in the invariant and assert an exact
     state. [fresh] also asserts the exact state; it is owned by threads (i.e.,
     there's a token needed to transition to [start].)  [started] and [finished]
     are *lower bounds*. We don't need "auth_finish" because the state will
     never change again, so [finished] is just as good. *)
  Context (auth_fresh fresh : iProp).
  Context (auth_start started finished : name → iProp).
  Hypothesis fresh_start :
    forall n, auth_fresh ★ fresh ⊢ pvs0 (auth_start n ★ started n).
  Hypotheses start_finish :
    forall n, auth_start n ⊢ pvs0 (finished n).

  Hypothesis fresh_not_start : forall n, auth_start n ★ fresh ⊢ False.
  Hypothesis fresh_not_finished : forall n, finished n ★ fresh ⊢ False.
  Hypothesis started_not_fresh : forall n, auth_fresh ★ started n ⊢ False.
  Hypothesis finished_not_start : forall n m, auth_start n ★ finished m ⊢ False.

  Hypothesis started_start_agree : forall n m, auth_start n ★ started m ⊢ n = m.
  Hypothesis started_finished_agree :
    forall n m, finished n ★ started m ⊢ n = m.
  Hypothesis finished_agree :
    forall n m, finished n ★ finished m ⊢ n = m.

  Hypothesis started_persistent : forall n, PersistentP (started n).
  Hypothesis finished_persistent : forall n, PersistentP (finished n).

  (* We have that we cannot view shift from the initial state to false
     (because the initial state is actually achievable). *)
  Hypothesis soundness : ¬ (auth_fresh ★ fresh ⊢ pvs1 False).

  (** Some general lemmas and proof mode compatibility. *)
  Lemma inv_open' i P R:
    inv i P ★ (P -★ pvs0 (P ★ pvs1 R)) ⊢ pvs1 R.
  Proof.
    iIntros "(#HiP & HP)". iApply pvs1_pvs1. iApply inv_open; last first.
    { iSplit; first done. iExact "HP". }
    iIntros "(HP & HPw)". by iApply "HPw".
  Qed.

  Lemma pvs1_intro P : P ⊢ pvs1 P.
  Proof. rewrite -pvs0_pvs1. apply pvs0_intro. Qed.

  Instance pvs0_mono' : Proper ((⊢) ==> (⊢)) pvs0.
  Proof. intros ?**. by apply pvs0_mono. Qed.
  Instance pvs0_proper : Proper ((⊣⊢) ==> (⊣⊢)) pvs0.
  Proof.
    intros P Q Heq.
    apply (anti_symm (⊢)); apply pvs0_mono; by rewrite ?Heq -?Heq.
  Qed.
  Instance pvs1_mono' : Proper ((⊢) ==> (⊢)) pvs1.
  Proof. intros ?**. by apply pvs1_mono. Qed.
  Instance pvs1_proper : Proper ((⊣⊢) ==> (⊣⊢)) pvs1.
  Proof.
    intros P Q Heq.
    apply (anti_symm (⊢)); apply pvs1_mono; by rewrite ?Heq -?Heq.
  Qed.

  Lemma pvs0_frame_r : forall P Q, (pvs0 P ★ Q) ⊢ pvs0 (P ★ Q).
  Proof.
    intros. rewrite comm pvs0_frame_l. apply pvs0_mono. by rewrite comm.
  Qed.
  Lemma pvs1_frame_r : forall P Q, (pvs1 P ★ Q) ⊢ pvs1 (P ★ Q).
  Proof.
    intros. rewrite comm pvs1_frame_l. apply pvs1_mono. by rewrite comm.
  Qed.

  Global Instance elim_pvs0_pvs0 P Q :
    ElimVs (pvs0 P) P (pvs0 Q) (pvs0 Q).
  Proof.
    rename Q0 into Q.
    rewrite /ElimVs. etrans; last eapply pvs0_pvs0.
    rewrite pvs0_frame_r. apply pvs0_mono. by rewrite uPred.wand_elim_r.
  Qed.

  Global Instance elim_pvs1_pvs1 P Q :
    ElimVs (pvs1 P) P (pvs1 Q) (pvs1 Q).
  Proof.
    rename Q0 into Q.
    rewrite /ElimVs. etrans; last eapply pvs1_pvs1.
    rewrite pvs1_frame_r. apply pvs1_mono. by rewrite uPred.wand_elim_r.
  Qed.

  Global Instance elim_pvs0_pvs1 P Q :
    ElimVs (pvs0 P) P (pvs1 Q) (pvs1 Q).
  Proof.
    rename Q0 into Q.
    rewrite /ElimVs. rewrite pvs0_pvs1. apply elim_pvs1_pvs1.
  Qed.

  Global Instance exists_split_pvs0 {A} P (Φ : A → iProp) :
    FromExist P Φ → FromExist (pvs0 P) (λ a, pvs0 (Φ a)).
  Proof.
    rewrite /FromExist=>HP. apply uPred.exist_elim=> a.
    apply pvs0_mono. by rewrite -HP -(uPred.exist_intro a).
  Qed.

  Global Instance exists_split_pvs1 {A} P (Φ : A → iProp) :
    FromExist P Φ → FromExist (pvs1 P) (λ a, pvs1 (Φ a)).
  Proof.
    rewrite /FromExist=>HP. apply uPred.exist_elim=> a.
    apply pvs1_mono. by rewrite -HP -(uPred.exist_intro a).
  Qed.

  (** Now to the actual counterexample. *)
  Definition saved (i : name) (P : iProp) : iProp :=
    ∃ F : name → iProp, P = F i ★ started i ★
      inv i (auth_fresh ∨ ∃ j, auth_start j ∨ (finished j ★ □F j)).

  Lemma saved_alloc (P : name → iProp) :
    auth_fresh ★ fresh ⊢ pvs1 (∃ i, saved i (P i)).
  Proof.
    iIntros "[Haf Hf]". iVs (inv_alloc (auth_fresh ∨ ∃ j, auth_start j ∨ (finished j ★ □P j)) with "[Haf]") as (i) "#Hi".
    { iLeft. done. }
    iExists i. iApply inv_open'. iSplit; first done. iIntros "[Haf|Has]"; last first.
    { iExFalso. iDestruct "Has" as (j) "[Has | [Haf _]]".
      - iApply fresh_not_start. iSplitL "Has"; done.
      - iApply fresh_not_finished. iSplitL "Haf"; done. }
    iVs ((fresh_start i) with "[Hf Haf]") as "[Has #Hs]"; first by iFrame.
    iApply pvs0_intro. iSplitL.
    - iRight. iExists i. iLeft. done.
    - iApply pvs1_intro. iExists P. iSplit; first done. by iFrame "#".
  Qed.

  Lemma saved_cast i P Q :
    saved i P ★ saved i Q ★ □P ⊢ pvs1 (□Q).
  Proof.
    iIntros "(#HsP & #HsQ & #HP)". iDestruct "HsP" as (FP) "(% & HsP & HiP)".
    iApply (inv_open' i). iSplit; first done.
    iIntros "[HaP|HaP]".
    { iExFalso. iApply started_not_fresh. iSplit; done. }
    (* Can I state a view-shift and immediately run it? *)
    iAssert (pvs0 (finished i)) with "[HaP]" as "Hf".
    { iDestruct "HaP" as (j) "[Hs | [Hf _]]".
      - iApply start_finish. (* FIXME: iPoseProof as "%" calls the assertion "%" instead of moving to the Coq context. *)
        iPoseProof (started_start_agree with "[#]") as "H"; first by iSplit.
        iDestruct "H" as %<-. done.
      - iApply pvs0_intro. iPoseProof (started_finished_agree with "[#]") as "H"; first by iSplit.
        iDestruct "H" as %<-. done. }
    iVs "Hf" as "#Hf". iApply pvs0_intro. iSplitL.
    { iRight. iExists i. iRight. subst. eauto. }
    iDestruct "HsQ" as (FQ) "(% & HsQ & HiQ)".
    iApply (inv_open' i). iSplit; first iExact "HiQ".
    iIntros "[HaQ | HaQ]".
    { iExFalso. iApply started_not_fresh. iSplit; done. }
    iDestruct "HaQ" as (j) "[HaS | #[Hf' HQ]]".
    { iExFalso. iApply finished_not_start. eauto. }
    iApply pvs0_intro. iSplitL.
    { iRight. iExists j. eauto. }
    iPoseProof (finished_agree with "[#]") as "H".
    { iFrame "Hf Hf'". done. }
    iDestruct "H" as %<-. iApply pvs1_intro. subst Q. done.
  Qed.

(*
Now, define:

N(P) :=  box(P ==> False)
A[i] :=  Exists P. N(P) * i |-> P

Notice that A[i] => box(A[i]).

OK, now we are going to prove that True ==> False.

First we allocate some k s.t. k |-> A[k], which we know we can do
because of the axiom for |->.

Claim 2: N(A[k]).

Proof:
- Suppose A[k].  So, box(A[k]).  So, A[k] * A[k].
- So there is some P s.t. A[k] * N(P) * k |-> P.
- Since k |-> A(k), by Claim 1 we can view shift to P * N(P).
- Hence, we can view shift to False.
QED.

Notice that in Iris proper all we could get on the third line of the
above proof is later(P) * N(P), which would not be enough to derive
the claim.

Claim 3: A[k].

Proof:
- By Claim 2, we have N(A(k)) * k |-> A[k].
- Thus, picking P := A[k], we have Exists P. N(P) * k |-> P, i.e. we have A[k].
QED.

Claim 2 and Claim 3 together view shift to False.
*)
End inv.
