module Resources.Core where

open import Prelude
open import Map
open import Lifts

infixl 2 _>>=_
infixr 1 _>=>_
infixr 1 _>>_
infixl 6 _<$>_ _<*>_

Effectful : ∀ {ρ} {R : Set ρ} α ψ -> Set (ρ ⊔ lsuc (α ⊔ ψ))
Effectful {R = R} α ψ = (A : Set α) -> (A -> R) -> Set ψ

Effect : ∀ {ρ} (R : Set ρ) α ψ -> Set (ρ ⊔ lsuc (α ⊔ ψ))
Effect R α ψ = R -> Effectful {R = R} α ψ

Simple : ∀ α ψ -> Set (lsuc (α ⊔ ψ))
Simple = Effect ⊤₀

effectsˡ : ∀ {n} -> Level ^ n -> Level ²^ n -> Level
effectsˡ ρs αψs = max (zipWith (λ{ ρ (α , ψ) -> ρ ⊔ lsuc (α ⊔ ψ) }) ρs αψs)

Effects : ∀ {n} {ρs : Level ^ n} -> Sets ρs -> (αψs : Level ²^ n) -> Set (effectsˡ ρs αψs)
Effects {0}      tt       tt             = ⊤
Effects {suc n} (R , Rs) ((α , ψ) , αψs) = Effect R α ψ × Effects Rs αψs

lookupᵉ : ∀ {n} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
        -> (i : Fin n)
        -> Effects Rs αψs
        -> Effect (lookupᵐ i Rs) (proj₁ (lookup i αψs)) (proj₂ (lookup i αψs))
lookupᵉ  zero   (Ψ , Ψs) = Ψ
lookupᵉ (suc i) (Ψ , Ψs) = lookupᵉ i Ψs

Resources = HList

r′ˡ : Level × Level -> Level -> Level
r′ˡ (α , ψ) ρ = α ⊔ ρ

effˡ : ∀ {n} -> Level ^ n -> Level ²^ n -> Level -> Level
effˡ ρs αψs β = max (map (lsuc ∘ proj₁) αψs)
              ⊔ max (zipWith r′ˡ αψs ρs)
              ⊔ max (map proj₂ αψs)
              ⊔ max (map proj₁ αψs)
              ⊔ β

data Eff {n β} {ρs : Level ^ n} {αψs : Level ²^ n}
         {Rs : Sets ρs} (Ψs : Effects Rs αψs) (B : Set β)
         : Resources Rs -> (B -> Resources Rs) -> Set (effˡ ρs αψs β) where
  return : ∀ {rs′} y -> Eff Ψs B (rs′ y) rs′
  call   : ∀ {rs rs′}
         -> (i : Fin n)
         -> (Lift∃ᵐ (lsuc ∘ proj₁) i αψs λ A ->
               Lift∃ᶻ r′ˡ i αψs ρs λ r′ ->
                 Lift∃ᵐ proj₂ i αψs {lookupᵉ i Ψs (lookupʰ i rs) A r′} λ _ ->
                   Lift∀ᵐ proj₁ i αψs λ x ->
                     Eff Ψs B (replaceʰ i (r′ x) rs) rs′)
         -> Eff Ψs B rs rs′

call′ : ∀ {n β} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
          {Ψs : Effects Rs αψs} {B : Set β} {rs rs′}
          i {A r′}
      -> lookupᵉ i Ψs (lookupʰ i rs) A r′
      -> (∀ x -> Eff Ψs B (replaceʰ i (r′ x) rs) rs′)
      -> Eff Ψs B rs rs′
call′ i a f = call i (lift∃ᵐ i (, lift∃ᶻ i (, lift∃ᵐ i (a , lift∀ᵐ i f))))

runLifts : ∀ {n β} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
             {Ψs : Effects Rs αψs} {B : Set β} {rs rs′}
             i
         -> (Lift∃ᵐ (lsuc ∘ proj₁) i αψs λ A ->
               Lift∃ᶻ r′ˡ i αψs ρs λ R′ ->
                 Lift∃ᵐ proj₂ i αψs {lookupᵉ i Ψs (lookupʰ i rs) A R′} λ _ ->
                   Lift∀ᵐ proj₁ i αψs λ x ->
                     Eff Ψs B (replaceʰ i (R′ x) rs) rs′)
         -> ∃₂ λ A R′ ->   lookupᵉ i Ψs (lookupʰ i rs) A R′
                         × ∀ x -> Eff Ψs B (replaceʰ i (R′ x) rs) rs′
runLifts i = second (second (second (lower∀ᵐ i) ∘ lower∃ᵐ i) ∘ lower∃ᶻ i) ∘ lower∃ᵐ i

runEff : ∀ {β} {B : Set β} -> Eff tt B tt _ -> B
runEff (return y)  = y
runEff (call () p)

invoke# : ∀ {n} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs} {Ψs : Effects Rs αψs} {rs}
            i {A r′}
        -> lookupᵉ i Ψs (lookupʰ i rs) A r′ -> Eff Ψs A rs (λ x -> replaceʰ i (r′ x) rs)
invoke# i a = call′ i a return

invoke₀ : ∀ {n ρ α ψ} {ρs : Level ^ n} {αψs : Level ²^ n} {R : Set ρ}
            {Rs : Sets ρs} {Ψ : Effect R α ψ} {Ψs : Effects Rs αψs} {r A r′ rs}
        -> Ψ r A r′ -> Eff (Ψ , Ψs) A (r , rs) (λ x -> r′ x , rs)
invoke₀ = invoke# zero

{-# TERMINATING #-}
_>>=_ : ∀ {n β γ} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
          {Ψs : Effects Rs αψs} {B : Set β} {C : Set γ} {rs rs′ rs′′}
      -> Eff Ψs B rs rs′ -> (∀ y -> Eff Ψs C (rs′ y) rs′′) -> Eff Ψs C rs rs′′
return y >>= g = g y
call i p >>= g = let , , a , f = runLifts i p in call′ i a λ x -> f x >>= g

_>=>_ : ∀ {n α β γ} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs} {Ψs : Effects Rs αψs}
          {A : Set α} {B : Set β} {C : Set γ} {rs₁′ : A -> Resources Rs} {rs₂′ rs₃′}
      -> (∀ x -> Eff Ψs B (rs₁′ x) rs₂′)
      -> (∀ y -> Eff Ψs C (rs₂′ y) rs₃′)
      -> (∀ x -> Eff Ψs C (rs₁′ x) rs₃′)
(f >=> g) x = f x >>= g

_>>_ : ∀ {n β γ} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
         {Ψs : Effects Rs αψs} {B : Set β} {C : Set γ} {rs₁ rs₂ rs′′}
     -> Eff Ψs B rs₁ (const rs₂) -> Eff Ψs C rs₂ rs′′ -> Eff Ψs C rs₁ rs′′
b >> c = b >>= const c

_<$>_ : ∀ {n β γ} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
          {Ψs : Effects Rs αψs} {B : Set β} {C : Set γ} {rs₁ rs₂}
      -> (B -> C) -> Eff Ψs B rs₁ (const rs₂) -> Eff Ψs C rs₁ (const rs₂)
g <$> b = b >>= return ∘ g

_<*>_ : ∀ {n β γ} {ρs : Level ^ n} {αψs : Level ²^ n} {Rs : Sets ρs}
          {Ψs : Effects Rs αψs} {B : Set β} {C : Set γ} {rs₁ rs₂ rs₃}
      -> Eff Ψs (B -> C) rs₁ (const rs₂) -> Eff Ψs B rs₂ (const rs₃) -> Eff Ψs C rs₁ (const rs₃)
d <*> b = d >>= _<$> b

{-# TERMINATING #-}
shift : ∀ {n α ρ ψ β} {ρs : Level ^ n} {αψs : Level ²^ n} {R : Set ρ} {Rs : Sets ρs}
          {Ψ : Effect R α ψ} {r} {Ψs : Effects Rs αψs} {B : Set β} {rs rs′}
      -> Eff Ψs B rs rs′ -> Eff (Ψ , Ψs) B (r , rs) (λ y -> r , rs′ y) 
shift (return y) = return y
shift (call i p) = let , , a , f = runLifts i p in call′ (suc i) a (shift ∘′ f)

embed : ∀ {n α ρ ψ} {ρs : Level ^ n} {αψs : Level ²^ n} {R : Set ρ} {Rs : Sets ρs}
          {Ψ : Effect R α ψ} {r A r′} {Ψs : Effects Rs αψs} {rs₁ rs₂}
      -> Eff Ψs (Ψ r A r′) rs₁ (const rs₂) -> Eff (Ψ , Ψs) A (r , rs₁) (λ x -> r′ x , rs₂)
embed a = shift a >>= invoke₀

{-# TERMINATING #-}
runEffM : ∀ {n α} {ρs : Level ^ n} {αψs : Level ²^ n} {M : ∀ {α} -> Set α -> Set α}
            {Rs : Sets ρs} {Ψs : Effects Rs αψs} {B : Set α} {rs rs′}
        -> (∀ {α} {A : Set α} -> A -> M A)
        -> (∀ {α β} {A : Set α} {B : Set β} -> M A -> (A -> M B) -> M B)
        -> (∀ i {r A r′} -> lookupᵉ i Ψs r A r′ -> M A)
        -> Eff Ψs B rs rs′
        -> M B
runEffM ret bind h (return y) = ret y
runEffM ret bind h (call i p) = let , , a , f = runLifts i p in
  bind (h i a) (runEffM ret bind h ∘′ f)

-- Too weak, just for demonstration purposes.
{-# TERMINATING #-}
execEff : ∀ {n ρ α ψ β γ} {ρs : Level ^ n} {αψs : Level ²^ n} {R : Set ρ} {Rs : Sets ρs}
            {Ψ : Effect R α ψ} {Ψs : Effects Rs αψs} {B : Set β} {C : B -> Set γ} {rs rs′}
        -> (∀ y -> C y)
        -> (∀ {r A r′ rs rs′} -> Ψ r A r′ -> (A -> Eff Ψs (Σ B C) rs rs′) -> Eff Ψs (Σ B C) rs rs′)
        -> Eff (Ψ , Ψs)  B       rs           rs′
        -> Eff  Ψs      (Σ B C) (tailʰ n rs) (tailʰ n ∘ rs′ ∘ proj₁)
execEff h k (return y) = return (y , h y)
execEff h k (call i p) with runLifts i p
... | , , a , f with i
... | zero   = k a (execEff h k ∘′ f)
... | suc i' = call′ i' a (execEff h k ∘′ f)
