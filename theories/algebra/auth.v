From iris.algebra Require Export view.
From iris.algebra Require Import proofmode_classes.
From iris.base_logic Require Import base_logic.
From iris Require Import options.

(** The authoritative camera with fractional authoritative elements. The camera
[auth] has 3 types of elements: the fractional authoritative element [●{q} a],
the full authoritative element [● a ≡ ●{1} a], and the fragment [◯ b] (of which
there can be several). Updates are only possible with the full authoritative
element [● a], while fractional authoritative elements have agreement, i.e.,
[✓ (●{p1} a1 ⋅ ●{p2} a2) → a1 ≡ a2]. *)

(** * Definition of the view relation *)
Definition auth_view_rel_raw {A : ucmraT} (n : nat) (a b : A) : Prop :=
  b ≼{n} a ∧ ✓{n} a.
Lemma auth_view_rel_raw_mono (A : ucmraT) n1 n2 (a1 a2 b1 b2 : A) :
  auth_view_rel_raw n1 a1 b1 → a1 ≡{n1}≡ a2 → b2 ≼{n1} b1 → n2 ≤ n1 →
  auth_view_rel_raw n2 a2 b2.
Proof.
  intros [??] Ha12 ??. split.
  - apply cmra_includedN_le with n1; [|done]. rewrite -Ha12. by trans b1.
  - apply cmra_validN_le with n1; [|lia]. by rewrite -Ha12.
Qed.
Lemma auth_view_rel_raw_valid (A : ucmraT) n (a b : A) :
  auth_view_rel_raw n a b → ✓{n} b.
Proof. intros [??]; eauto using cmra_validN_includedN. Qed.
Canonical Structure auth_view_rel {A : ucmraT} : view_rel A A :=
  ViewRel auth_view_rel_raw (auth_view_rel_raw_mono A) (auth_view_rel_raw_valid A).

Lemma auth_view_rel_unit {A : ucmraT} n (a : A) : auth_view_rel n a ε ↔ ✓{n} a.
Proof. split; [by intros [??]|]. split; auto using ucmra_unit_leastN. Qed.

Instance auth_view_rel_discrete {A : ucmraT} :
  CmraDiscrete A → ViewRelDiscrete (auth_view_rel (A:=A)).
Proof.
  intros ? n a b [??]; split.
  - by apply cmra_discrete_included_iff_0.
  - by apply cmra_discrete_valid_iff_0.
Qed.

(** * Definition and operations on auth *)
(** The type [auth] is not defined as a [Definition], but as a [Notation].
This way, one can use [auth A] with [A : Type] instead of [A : ucmraT], and let
canonical structure search determine the corresponding camera instance. *)
Notation auth A := (view (A:=A) (B:=A) auth_view_rel_raw).
Definition authO (A : ucmraT) : ofeT := viewO (A:=A) (B:=A) auth_view_rel.
Definition authR (A : ucmraT) : cmraT := viewR (A:=A) (B:=A) auth_view_rel.
Definition authUR (A : ucmraT) : ucmraT := viewUR (A:=A) (B:=A) auth_view_rel.

Definition auth_auth {A: ucmraT} : Qp → A → auth A := view_auth.
Definition auth_frag {A: ucmraT} : A → auth A := view_frag.

Typeclasses Opaque auth_auth auth_frag.

Instance: Params (@auth_auth) 2 := {}.
Instance: Params (@auth_frag) 1 := {}.

Notation "◯ a" := (auth_frag a) (at level 20).
Notation "●{ q } a" := (auth_auth q a) (at level 20, format "●{ q }  a").
Notation "● a" := (auth_auth 1 a) (at level 20).

(** * Laws *)
Section auth.
  Context {A : ucmraT}.
  Implicit Types a b : A.
  Implicit Types x y : auth A.

  Global Instance auth_auth_ne q : NonExpansive (@auth_auth A q).
  Proof. rewrite /auth_auth. apply _. Qed.
  Global Instance auth_auth_proper q : Proper ((≡) ==> (≡)) (@auth_auth A q).
  Proof. rewrite /auth_auth. apply _. Qed.
  Global Instance auth_frag_ne : NonExpansive (@auth_frag A).
  Proof. rewrite /auth_frag. apply _. Qed.
  Global Instance auth_frag_proper : Proper ((≡) ==> (≡)) (@auth_frag A).
  Proof. rewrite /auth_frag. apply _. Qed.

  Global Instance auth_auth_dist_inj n : Inj2 (=) (dist n) (dist n) (@auth_auth A).
  Proof. rewrite /auth_auth. apply _. Qed.
  Global Instance auth_auth_inj : Inj2 (=) (≡) (≡) (@auth_auth A).
  Proof. rewrite /auth_auth. apply _. Qed.
  Global Instance auth_frag_dist_inj n : Inj (dist n) (dist n) (@auth_frag A).
  Proof. rewrite /auth_frag. apply _. Qed.
  Global Instance auth_frag_inj : Inj (≡) (≡) (@auth_frag A).
  Proof. rewrite /auth_frag. apply _. Qed.

  Lemma auth_auth_frac_validN n q a : ✓{n} (●{q} a) ↔ ✓{n} q ∧ ✓{n} a.
  Proof. by rewrite view_auth_frac_validN auth_view_rel_unit. Qed.
  Lemma auth_auth_validN n a : ✓{n} (● a) ↔ ✓{n} a.
  Proof. by rewrite view_auth_validN auth_view_rel_unit. Qed.
  Lemma auth_frag_validN n a : ✓{n} (◯ a) ↔ ✓{n} a.
  Proof. apply view_frag_validN. Qed.
  Lemma auth_both_frac_validN n q a b :
    ✓{n} (●{q} a ⋅ ◯ b) ↔ ✓{n} q ∧ b ≼{n} a ∧ ✓{n} a.
  Proof. apply view_both_frac_validN. Qed.
  Lemma auth_both_validN n a b : ✓{n} (● a ⋅ ◯ b) ↔ b ≼{n} a ∧ ✓{n} a.
  Proof. apply view_both_validN. Qed.

  Lemma auth_auth_frac_valid q a : ✓ (●{q} a) ↔ ✓ q ∧ ✓ a.
  Proof.
    rewrite view_auth_frac_valid !cmra_valid_validN.
    by setoid_rewrite auth_view_rel_unit.
  Qed.
  Lemma auth_auth_valid a : ✓ (● a) ↔ ✓ a.
  Proof.
    rewrite view_auth_valid !cmra_valid_validN.
    by setoid_rewrite auth_view_rel_unit.
  Qed.
  Lemma auth_frag_valid a : ✓ (◯ a) ↔ ✓ a.
  Proof. apply view_frag_valid. Qed.

  (** These lemma statements are a bit awkward as we cannot possibly extract a
  single witness for [b ≼ a] from validity, we have to make do with one witness
  per step-index, i.e., [∀ n, b ≼{n} a]. *)
  Lemma auth_both_frac_valid q a b :
    ✓ (●{q} a ⋅ ◯ b) ↔ ✓ q ∧ (∀ n, b ≼{n} a) ∧ ✓ a.
  Proof.
    rewrite view_both_frac_valid. apply and_iff_compat_l. split.
    - intros Hrel. split.
      + intros n. by destruct (Hrel n).
      + apply cmra_valid_validN=> n. by destruct (Hrel n).
    - intros [Hincl Hval] n. split; [done|by apply cmra_valid_validN].
  Qed.
  Lemma auth_both_valid a b :
    ✓ (● a ⋅ ◯ b) ↔ (∀ n, b ≼{n} a) ∧ ✓ a.
  Proof. rewrite auth_both_frac_valid frac_valid'. naive_solver. Qed.

  (* The reverse direction of the two lemmas below only holds if the camera is
  discrete. *)
  Lemma auth_both_frac_valid_2 q a b : ✓ q → ✓ a → b ≼ a → ✓ (●{q} a ⋅ ◯ b).
  Proof.
    intros. apply auth_both_frac_valid.
    naive_solver eauto using cmra_included_includedN.
  Qed.
  Lemma auth_both_valid_2 a b : ✓ a → b ≼ a → ✓ (● a ⋅ ◯ b).
  Proof. intros ??. by apply auth_both_frac_valid_2. Qed.

  Lemma auth_both_frac_valid_discrete `{!CmraDiscrete A} q a b :
    ✓ (●{q} a ⋅ ◯ b) ↔ ✓ q ∧ b ≼ a ∧ ✓ a.
  Proof.
    rewrite auth_both_frac_valid. setoid_rewrite <-cmra_discrete_included_iff.
    naive_solver eauto using O.
  Qed.
  Lemma auth_both_valid_discrete `{!CmraDiscrete A} a b :
    ✓ (● a ⋅ ◯ b) ↔ b ≼ a ∧ ✓ a.
  Proof. rewrite auth_both_frac_valid_discrete frac_valid'. naive_solver. Qed.

  Global Instance auth_ofe_discrete : OfeDiscrete A → OfeDiscrete (authO A).
  Proof. apply _. Qed.
  Global Instance auth_auth_discrete q a :
    Discrete a → Discrete (ε : A) → Discrete (●{q} a).
  Proof. rewrite /auth_auth. apply _. Qed.
  Global Instance auth_frag_discrete a : Discrete a → Discrete (◯ a).
  Proof. rewrite /auth_frag. apply _. Qed.
  Global Instance auth_cmra_discrete : CmraDiscrete A → CmraDiscrete (authR A).
  Proof. apply _. Qed.

  Lemma auth_auth_frac_op p q a : ●{p + q} a ≡ ●{p} a ⋅ ●{q} a.
  Proof. apply view_auth_frac_op. Qed.
  Lemma auth_auth_frac_op_invN n p a q b : ✓{n} (●{p} a ⋅ ●{q} b) → a ≡{n}≡ b.
  Proof. apply view_auth_frac_op_invN. Qed.
  Lemma auth_auth_frac_op_inv p a q b : ✓ (●{p} a ⋅ ●{q} b) → a ≡ b.
  Proof. apply view_auth_frac_op_inv. Qed.
  Lemma auth_auth_frac_op_inv_L `{!LeibnizEquiv A} q a p b :
    ✓ (●{p} a ⋅ ●{q} b) → a = b.
  Proof. by apply view_auth_frac_op_inv_L. Qed.
  Global Instance is_op_auth_auth_frac q q1 q2 a :
    IsOp q q1 q2 → IsOp' (●{q} a) (●{q1} a) (●{q2} a).
  Proof. rewrite /auth_auth. apply _. Qed.

  Lemma auth_frag_op a b : ◯ (a ⋅ b) = ◯ a ⋅ ◯ b.
  Proof. apply view_frag_op. Qed.
  Lemma auth_frag_mono a b : a ≼ b → ◯ a ≼ ◯ b.
  Proof. apply view_frag_mono. Qed.
  Lemma auth_frag_core a : core (◯ a) = ◯ (core a).
  Proof. apply view_frag_core. Qed.
  Global Instance auth_frag_core_id a : CoreId a → CoreId (◯ a).
  Proof. rewrite /auth_frag. apply _. Qed.
  Global Instance is_op_auth_frag a b1 b2 :
    IsOp a b1 b2 → IsOp' (◯ a) (◯ b1) (◯ b2).
  Proof. rewrite /auth_frag. apply _. Qed.
  Global Instance auth_frag_sep_homomorphism :
    MonoidHomomorphism op op (≡) (@auth_frag A).
  Proof. rewrite /auth_frag. apply _. Qed.

  Lemma big_opL_auth_frag {B} (g : nat → B → A) (l : list B) :
    (◯ [^op list] k↦x ∈ l, g k x) ≡ [^op list] k↦x ∈ l, ◯ (g k x).
  Proof. apply (big_opL_commute _). Qed.
  Lemma big_opM_auth_frag `{Countable K} {B} (g : K → B → A) (m : gmap K B) :
    (◯ [^op map] k↦x ∈ m, g k x) ≡ [^op map] k↦x ∈ m, ◯ (g k x).
  Proof. apply (big_opM_commute _). Qed.
  Lemma big_opS_auth_frag `{Countable B} (g : B → A) (X : gset B) :
    (◯ [^op set] x ∈ X, g x) ≡ [^op set] x ∈ X, ◯ (g x).
  Proof. apply (big_opS_commute _). Qed.
  Lemma big_opMS_auth_frag `{Countable B} (g : B → A) (X : gmultiset B) :
    (◯ [^op mset] x ∈ X, g x) ≡ [^op mset] x ∈ X, ◯ (g x).
  Proof. apply (big_opMS_commute _). Qed.

  (** Inclusion *)
  Lemma auth_auth_includedN n p1 p2 a1 a2 b :
    ●{p1} a1 ≼{n} ●{p2} a2 ⋅ ◯ b ↔ (p1 ≤ p2)%Qc ∧ a1 ≡{n}≡ a2.
  Proof. apply view_auth_includedN. Qed.
  Lemma auth_auth_included p1 p2 a1 a2 b :
    ●{p1} a1 ≼ ●{p2} a2 ⋅ ◯ b ↔ (p1 ≤ p2)%Qc ∧ a1 ≡ a2.
  Proof. apply view_auth_included. Qed.

  Lemma auth_frag_includedN n p a b1 b2 :
    ◯ b1 ≼{n} ●{p} a ⋅ ◯ b2 ↔ b1 ≼{n} b2.
  Proof. apply view_frag_includedN. Qed.
  Lemma auth_frag_included p a b1 b2 :
    ◯ b1 ≼ ●{p} a ⋅ ◯ b2 ↔ b1 ≼ b2.
  Proof. apply view_frag_included. Qed.

  (** Internalized properties *)
  Lemma auth_auth_validI {M} q (a b: A) :
    ✓ (●{q} a) ⊣⊢@{uPredI M} ✓ q ∧ ✓ a.
  Proof.
    apply view_auth_validI=> n. uPred.unseal; split; [|by intros [??]].
    split; [|done]. apply ucmra_unit_leastN.
  Qed.
  Lemma auth_frag_validI {M} (a : A):
    ✓ (◯ a) ⊣⊢@{uPredI M} ✓ a.
  Proof. apply view_frag_validI. Qed.
  Lemma auth_both_validI {M} q (a b: A) :
    ✓ (●{q} a ⋅ ◯ b) ⊣⊢@{uPredI M} ✓ q ∧ (∃ c, a ≡ b ⋅ c) ∧ ✓ a.
  Proof. apply view_both_validI=> n. by uPred.unseal. Qed.

  (** Updates *)
  Lemma auth_update a b a' b' :
    (a,b) ~l~> (a',b') → ● a ⋅ ◯ b ~~> ● a' ⋅ ◯ b'.
  Proof.
    intros Hup. apply view_update=> n bf [[bf' Haeq] Hav].
    destruct (Hup n (Some (bf ⋅ bf'))); simpl in *; [done|by rewrite assoc|].
    split; [|done]. exists bf'. by rewrite -assoc.
  Qed.

  Lemma auth_update_alloc a a' b' : (a,ε) ~l~> (a',b') → ● a ~~> ● a' ⋅ ◯ b'.
  Proof. intros. rewrite -(right_id _ _ (● a)). by apply auth_update. Qed.
  Lemma auth_update_dealloc a b a' : (a,b) ~l~> (a',ε) → ● a ⋅ ◯ b ~~> ● a'.
  Proof. intros. rewrite -(right_id _ _ (● a')). by apply auth_update. Qed.
  Lemma auth_update_auth a a' b' : (a,ε) ~l~> (a',b') → ● a ~~> ● a'.
  Proof.
    intros. etrans; first exact: auth_update_alloc.
    exact: cmra_update_op_l.
  Qed.

  Lemma auth_update_core_id q a b `{!CoreId b} :
    b ≼ a → ●{q} a ~~> ●{q} a ⋅ ◯ b.
  Proof.
    intros Ha%(core_id_extract _ _). apply view_update_alloc_frac=> n bf [??].
    split; [|done]. rewrite Ha (comm _ a). by apply cmra_monoN_l.
  Qed.

  Lemma auth_local_update a b0 b1 a' b0' b1' :
    (b0, b1) ~l~> (b0', b1') → b0' ≼ a' → ✓ a' →
    (● a ⋅ ◯ b0, ● a ⋅ ◯ b1) ~l~> (● a' ⋅ ◯ b0', ● a' ⋅ ◯ b1').
  Proof.
    intros. apply view_local_update; [done|]=> n [??]. split.
    - by apply cmra_included_includedN.
    - by apply cmra_valid_validN.
  Qed.
End auth.

(** * Functor *)
Program Definition authURF (F : urFunctor) : urFunctor := {|
  urFunctor_car A _ B _ := authUR (urFunctor_car F A B);
  urFunctor_map A1 _ A2 _ B1 _ B2 _ fg :=
    viewO_map (urFunctor_map F fg) (urFunctor_map F fg)
|}.
Next Obligation.
  intros F A1 ? A2 ? B1 ? B2 ? n f g Hfg.
  apply viewO_map_ne; by apply urFunctor_map_ne.
Qed.
Next Obligation.
  intros F A ? B ? x; simpl in *. rewrite -{2}(view_map_id x).
  apply (view_map_ext _ _ _ _)=> y; apply urFunctor_map_id.
Qed.
Next Obligation.
  intros F A1 ? A2 ? A3 ? B1 ? B2 ? B3 ? f g f' g' x; simpl in *.
  rewrite -view_map_compose.
  apply (view_map_ext _ _ _ _)=> y; apply urFunctor_map_compose.
Qed.
Next Obligation.
  intros F A1 ? A2 ? B1 ? B2 ? fg; simpl.
  apply view_map_cmra_morphism; [apply _..|]=> n a b [??]; split.
  - by apply (cmra_morphism_monotoneN _).
  - by apply (cmra_morphism_validN _).
Qed.

Instance authURF_contractive F :
  urFunctorContractive F → urFunctorContractive (authURF F).
Proof.
  intros ? A1 ? A2 ? B1 ? B2 ? n f g Hfg.
  apply viewO_map_ne; by apply urFunctor_map_contractive.
Qed.

Definition authRF (F : urFunctor) :=
  urFunctor_to_rFunctor (authURF F).
