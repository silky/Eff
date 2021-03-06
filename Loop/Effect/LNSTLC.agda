{-# OPTIONS --type-in-type --no-positivity-check #-}

-- The whole module doesn't make any sense.
-- The only way to interpret (Termᴱ Ψs rs₁ Γ σ rs₂) where `Ψs' is non-empty
-- is via the `HBreak' effect (see the `evalTermᴱ' function), which breaks purity.
-- Still, it's a nice example of why higher-order effects might be useful.

-- Doesn't type check currently, because `Loop.Core` is under reconstruction.
module Loop.Effect.LNSTLC where

open import Loop
open import Loop.Effect.Break

infixr 6 _⇒_
infixl 5 _▻_
infixr 4 vs_
infixr 0 ƛ_
infixl 6 _·_
infixr 5 _::_

data Type : Set where
  nat  : Type
  list : Type -> Type
  _⇒_  : Type -> Type -> Type

⟦_⟧ : Type -> Set
⟦ nat    ⟧ = ℕ
⟦ list σ ⟧ = List ⟦ σ ⟧
⟦ σ ⇒ τ  ⟧ = ⟦ σ ⟧ -> ⟦ τ ⟧

data Con : Set where
  ε   : Con
  _▻_ : Con -> Type -> Con

data In σ : Con -> Set where
  vz  : ∀ {Γ}   -> In σ (Γ ▻ σ)
  vs_ : ∀ {Γ τ} -> In σ  Γ      -> In σ (Γ ▻ τ)

data Env : Con -> Set where
  ∅   : Env ε
  _▷_ : ∀ {Γ σ} -> Env Γ -> ⟦ σ ⟧ -> Env (Γ ▻ σ)

lookupEnv : ∀ {Γ σ} -> In σ Γ -> Env Γ -> ⟦ σ ⟧
lookupEnv  vz    (ρ ▷ x) = x
lookupEnv (vs v) (ρ ▷ x) = lookupEnv v ρ

mutual
  Term : ∀ {Rs} -> Effects Rs -> Resources Rs -> Con -> Type -> Resources Rs -> Set
  Term  Ψs rs₁ Γ σ rs₂ = HTerm Γ Ψs rs₁ ⟦ σ ⟧ (const rs₂)

  -- A funny problem: we need to put contexts somewhere, no matter where,
  -- but they just don't fit anywhere. The current version (`HTerm' is indexed by a context)
  -- looks restrictive (that claim needs a proof). We could put contexts into resources
  -- at the cost of introducing a dummy effect, but it looks silly and doesn't solve all problems.
  -- We could make `EffOver' return contexts, but then it would be impossible to use simple _>>=_
  -- and other combinators, which is annoying (and I also haven't tried this solution).
  Termᴱ : ∀ {Rs} -> Effects Rs -> Resources Rs -> Con -> Type -> Resources Rs -> Set
  Termᴱ Ψs rs₁ Γ σ rs₂ = EffOver (HTerm Γ ∷ []) Ψs rs₁ ⟦ σ ⟧ (const rs₂)

  data HTerm Γ : HigherEffect where
    Pure  : ∀ {Rs rs σ} {Ψs : Effects Rs} -> ⟦ σ ⟧  -> Term Ψs rs Γ σ rs
    Var   : ∀ {Rs rs σ} {Ψs : Effects Rs} -> In σ Γ -> Term Ψs rs Γ σ rs
    Lam   :                                       ∀ {Rs rs₁ rs₂     σ τ} {Ψs : Effects Rs}
          -> Termᴱ Ψs rs₁ (Γ ▻ σ)  τ          rs₂
          -> Term  Ψs rs₁  Γ      (σ ⇒ τ)     rs₂
    App   :                                       ∀ {Rs rs₁ rs₂ rs₃ σ τ} {Ψs : Effects Rs}
          -> Termᴱ Ψs rs₁  Γ      (σ ⇒ τ)     rs₂
          -> Termᴱ Ψs rs₂  Γ       σ          rs₃
          -> Term  Ψs rs₁  Γ       τ          rs₃
    Z     :                                       ∀ {Rs rs             } {Ψs : Effects Rs}
          -> Term  Ψs rs   Γ       nat        rs
    S     :                                       ∀ {Rs rs₁ rs₂        } {Ψs : Effects Rs}
          -> Termᴱ Ψs rs₁  Γ       nat        rs₂
          -> Term  Ψs rs₁  Γ       nat        rs₂
    Fold  :                                       ∀ {Rs rs₁ rs₂ rs₃ σ  } {Ψs : Effects Rs}
          -> Termᴱ Ψs rs₃  Γ      (σ ⇒ σ)     rs₃
          -> Termᴱ Ψs rs₂  Γ       σ          rs₃
          -> Termᴱ Ψs rs₁  Γ       nat        rs₂
          -> Term  Ψs rs₁  Γ       σ          rs₃
    Nil   :                                       ∀ {Rs rs          σ  } {Ψs : Effects Rs}
          -> Term  Ψs rs   Γ      (list σ)    rs
    Cons  :                                       ∀ {Rs rs₁ rs₂ rs₃ σ  } {Ψs : Effects Rs}
          -> Termᴱ Ψs rs₁  Γ       σ          rs₂
          -> Termᴱ Ψs rs₂  Γ      (list σ)    rs₃
          -> Term  Ψs rs₁  Γ      (list σ)    rs₃
    Foldr :                                       ∀ {Rs rs₁ rs₂ rs₃ σ τ} {Ψs : Effects Rs}
          -> Termᴱ Ψs rs₃  Γ      (σ ⇒ τ ⇒ τ) rs₃
          -> Termᴱ Ψs rs₂  Γ       τ          rs₃
          -> Termᴱ Ψs rs₁  Γ      (list σ)    rs₂
          -> Term  Ψs rs₁  Γ       τ          rs₃

var : ∀ {Rs rs Γ σ} {Ψs : Effects Rs} -> In σ Γ -> Termᴱ Ψs rs Γ σ rs
var v = hinvoke (Var v)

ƛ_ : ∀ {Rs rs₁ rs₂ Γ σ τ} {Ψs : Effects Rs}
   -> Termᴱ Ψs rs₁ (Γ ▻ σ) τ rs₂ -> Termᴱ Ψs rs₁ Γ (σ ⇒ τ) rs₂
ƛ b = hinvoke (Lam b)

_·_ : ∀ {Rs rs₁ rs₂ rs₃ Γ σ τ} {Ψs : Effects Rs}
    -> Termᴱ Ψs rs₁ Γ (σ ⇒ τ) rs₂ -> Termᴱ Ψs rs₂ Γ σ rs₃ -> Termᴱ Ψs rs₁ Γ τ rs₃
f · x = hinvoke (App f x)

z : ∀ {Rs rs Γ} {Ψs : Effects Rs} -> Termᴱ Ψs rs Γ nat rs
z = hinvoke Z

s : ∀ {Rs rs₁ rs₂ Γ} {Ψs : Effects Rs} -> Termᴱ Ψs rs₁ Γ nat rs₂ -> Termᴱ Ψs rs₁ Γ nat rs₂
s n = hinvoke (S n)

tfold : ∀ {Rs rs₁ rs₂ rs₃ Γ σ} {Ψs : Effects Rs}
      -> Termᴱ Ψs rs₃ Γ (σ ⇒ σ) rs₃
      -> Termᴱ Ψs rs₂ Γ  σ      rs₃
      -> Termᴱ Ψs rs₁ Γ  nat    rs₂
      -> Termᴱ Ψs rs₁ Γ  σ      rs₃
tfold f z n = hinvoke (Fold f z n)

nil : ∀ {Rs rs Γ σ} {Ψs : Effects Rs} -> Termᴱ Ψs rs Γ (list σ) rs
nil = hinvoke Nil

_::_ : ∀ {Rs rs₁ rs₂ rs₃ Γ σ} {Ψs : Effects Rs}
     -> Termᴱ Ψs rs₁ Γ σ rs₂ -> Termᴱ Ψs rs₂ Γ (list σ) rs₃ -> Termᴱ Ψs rs₁ Γ (list σ) rs₃
x :: xs = hinvoke (Cons x xs)

tfoldr : ∀ {Rs rs₁ rs₂ rs₃ Γ σ τ} {Ψs : Effects Rs}
       -> Termᴱ Ψs rs₃  Γ (σ ⇒ τ ⇒ τ) rs₃
       -> Termᴱ Ψs rs₂  Γ  τ          rs₃
       -> Termᴱ Ψs rs₁  Γ (list σ)    rs₂
       -> Termᴱ Ψs rs₁  Γ  τ          rs₃
tfoldr f z xs = hinvoke (Foldr f z xs)

runTermᴱ : ∀ {Γ σ} -> Env Γ -> Termᴱ tt tt Γ σ tt -> ⟦ σ ⟧
runTermᴱ ρ (return x)                             = x
runTermᴱ ρ (wcall (inj₁  ())                   k)
runTermᴱ ρ (wcall (inj₂ (inj₂  ()))            k)
runTermᴱ ρ (wcall (inj₂ (inj₁ (Pure x)))       k) = runTermᴱ ρ (k  x)
runTermᴱ ρ (wcall (inj₂ (inj₁ (Var v)))        k) = runTermᴱ ρ (k (lookupEnv v ρ))
runTermᴱ ρ (wcall (inj₂ (inj₁ (Lam b)))        k) = runTermᴱ ρ (k (λ x -> runTermᴱ (ρ ▷ x) b))
runTermᴱ ρ (wcall (inj₂ (inj₁ (App f x)))      k) = runTermᴱ ρ (k (runTermᴱ ρ f (runTermᴱ ρ x)))
runTermᴱ ρ (wcall (inj₂ (inj₁  Z))             k) = runTermᴱ ρ (k  0)
runTermᴱ ρ (wcall (inj₂ (inj₁ (S n)))          k) = runTermᴱ ρ (k (suc (runTermᴱ ρ n)))
runTermᴱ ρ (wcall (inj₂ (inj₁ (Fold  f z n)))  k) = runTermᴱ ρ (k (fold   (runTermᴱ ρ z)
                                                                          (runTermᴱ ρ f)
                                                                          (runTermᴱ ρ n)))
runTermᴱ ρ (wcall (inj₂ (inj₁  Nil))           k) = runTermᴱ ρ (k  [])
runTermᴱ ρ (wcall (inj₂ (inj₁ (Cons x xs)))    k) = runTermᴱ ρ (k (runTermᴱ ρ x ∷ runTermᴱ ρ xs))
runTermᴱ ρ (wcall (inj₂ (inj₁ (Foldr f z xs))) k) = runTermᴱ ρ (k (lfoldr (runTermᴱ ρ f)
                                                                          (runTermᴱ ρ z)
                                                                          (runTermᴱ ρ xs)))

{-# TERMINATING #-}
evalTermᴱ : ∀ {Rs rs₁ rs₂ Γ σ} {Ψs : Effects Rs}
          -> Env Γ -> Termᴱ Ψs rs₁ Γ σ rs₂ -> Breakᴱ Ψs rs₁ ⟦ σ ⟧ rs₂
evalTermᴱ ρ (return x)                             = return x
evalTermᴱ ρ (wcall (inj₁  a)                    k) = wcall (inj₁ a) (evalTermᴱ ρ ∘′ k)
evalTermᴱ ρ (wcall (inj₂ (inj₂  ()))            k)
evalTermᴱ ρ (wcall (inj₂ (inj₁ (Pure x)))       k) = evalTermᴱ ρ (k x)
evalTermᴱ ρ (wcall (inj₂ (inj₁ (Var v)))        k) = evalTermᴱ ρ (k (lookupEnv v ρ))
evalTermᴱ ρ (wcall (inj₂ (inj₁ (Lam b)))        k) =
  (lam λ x -> evalTermᴱ (ρ ▷ x) b) >>= evalTermᴱ ρ ∘ k
evalTermᴱ ρ (wcall (inj₂ (inj₁ (App f x)))      k) =
  evalTermᴱ ρ f <*> evalTermᴱ ρ x >>= evalTermᴱ ρ ∘ k
evalTermᴱ ρ (wcall (inj₂ (inj₁  Z))             k) = evalTermᴱ ρ (k 0)
evalTermᴱ ρ (wcall (inj₂ (inj₁ (S n)))          k) = evalTermᴱ ρ n >>= evalTermᴱ ρ ∘ k ∘ suc
evalTermᴱ ρ (wcall (inj₂ (inj₁ (Fold  f z n)))  k) =
  evalTermᴱ ρ n >>= λ nₚ -> fold (evalTermᴱ ρ z)
                                 (λ x -> flip _$_ <$> x <*> evalTermᴱ ρ f)
                                  nₚ
                              >>= evalTermᴱ ρ ∘ k
evalTermᴱ ρ (wcall (inj₂ (inj₁  Nil))           k) = evalTermᴱ ρ (k [])
evalTermᴱ ρ (wcall (inj₂ (inj₁ (Cons x xs)))    k) =
  _∷_ <$> evalTermᴱ ρ x <*> evalTermᴱ ρ xs >>= evalTermᴱ ρ ∘ k
evalTermᴱ ρ (wcall (inj₂ (inj₁ (Foldr f z xs))) k) =
  evalTermᴱ ρ xs >>= λ xsₚ -> lfoldr (λ xₚ y -> (λ yₚ fₚ -> fₚ xₚ yₚ) <$> y <*> evalTermᴱ ρ f)
                                     (evalTermᴱ ρ z)
                                      xsₚ
                                >>= evalTermᴱ ρ ∘ k



open import Loop.Effect.State

A : ∀ {σ τ} -> Termᴱ tt tt ε ((σ ⇒ τ) ⇒ σ ⇒ τ) tt
A = ƛ ƛ var (vs vz) · var vz

private
  test₁ : Termᴱ (State , tt) (⊤ , tt) ε ((nat ⇒ nat) ⇒ nat ⇒ nat) (ℕ , tt)
  test₁ = ƛ ƛ var vz >>= zap ⊤ >> var (vs vz) · get

  test₂ : Termᴱ (State , tt) (⊤ , tt) ε ((nat ⇒ nat) ⇒ nat ⇒ nat) (ℕ , tt)
  test₂ = ƛ var vz >>= (λ f -> zap ⊤ (f 0)) >> (ƛ var (vs vz) · get)
