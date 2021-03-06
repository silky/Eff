{-# OPTIONS --type-in-type #-}

module Loop.Core where

open import Prelude

infix  3 _∈_ _∈₁_ _∈²_
infixl 2 _>>=_
infixr 1 _>>_
infixl 6 _<$>_ _<*>_

List₁ : ∀ {A} (B : A -> Set) -> List A -> Set
List₁ B  []      = ⊤
List₁ B (x ∷ xs) = B x × List₁ B xs

lmap₁ : ∀ {A} {B : A -> Set} -> (∀ x -> B x) -> (xs : List A) -> List₁ B xs
lmap₁ f  []      = tt
lmap₁ f (x ∷ xs) = f x , lmap₁ f xs

head₁ : ∀ {A} {B : A -> Set} {x xs} -> List₁ B (x ∷ xs) -> B x
head₁ (y , ys) = y

tail₁ : ∀ {A} {B : A -> Set} {x xs} -> List₁ B (x ∷ xs) -> List₁ B xs
tail₁ (y , ys) = ys

_∈_ : ∀ {A} -> A -> List A -> Set
y ∈  []      = ⊥
y ∈ (x ∷ xs) = y ≡ x ⊎ y ∈ xs

data _∈₁_ {A} {B : A -> Set} {x} (y : B x) : ∀ {xs} -> List₁ B xs -> Set where
  here₁  : ∀ {xs} {ys : List₁ B xs} -> y ∈₁ y , ys
  there₁ : ∀ {x xs} {z : B x} {ys : List₁ B xs} -> y ∈₁ ys -> y ∈₁ z , ys 

_∈²_ : ∀ {A} {B C : A -> Set} {x xs} -> B x × C x -> List₁ B xs × List₁ C xs -> Set
_∈²_ {x = x₁} {[]}     (y₁ , z₁) (tt        , tt      )  = ⊥
_∈²_ {x = x₁} {x₂ ∷ _} (y₁ , z₁) ((y₂ , ys) , (z₂ , zs)) = x₁ ≡ x₂ × y₁ ≅ y₂ × z₁ ≅ z₂
                                                        ⊎ y₁ , z₁ ∈² ys , zs

un∈ʳ : ∀ {A} {B C : A -> Set} {x xs} {y : B x} {z : C x} {ys : List₁ B xs} {zs : List₁ C xs}
     -> y , z ∈² ys , zs -> z ∈₁ zs
un∈ʳ {xs = []}     ()
un∈ʳ {xs = _ ∷ _} (inj₁ (refl , hrefl , hrefl)) = here₁
un∈ʳ {xs = _ ∷ _} (inj₂ p)                      = there₁ (un∈ʳ p)

replace₁ : ∀ {A} {B : A -> Set} {x} {xs : List A} {y : B x} {ys : List₁ B xs}
         -> B x -> y ∈₁ ys -> List₁ B xs
replace₁ {ys = y , ys} z  here₁     = z , ys
replace₁ {ys = y , ys} z (there₁ p) = y , replace₁ z p

--------------------

Sets : Set
Sets = List Set

HList : Sets -> Set
HList = List₁ id

Resources = HList

Effectful : ∀ {R} -> Set
Effectful {R} = (A : Set) -> (A -> R) -> Set
 
Effect : Set -> Set
Effect R = R -> Effectful {R}

Effects : Sets -> Set
Effects = List₁ Effect

-- The (∀ {Rs}) part might be too restrictive.
HigherEffect : Set
HigherEffect = ∀ {Rs} -> Effects Rs -> Effect (Resources Rs)

HigherEffects : Set
HigherEffects = List HigherEffect

data Unionᵉ : HigherEffect where
  hereᵉ  : ∀ {R Rs r A r′ rs}  {Ψ : Effect R} {Ψs : Effects Rs}
         -> Ψ r A r′ -> Unionᵉ (Ψ , Ψs) (r , rs) A (λ x -> r′ x , rs)
  thereᵉ : ∀ {R Rs r A rs rs′} {Ψ : Effect R} {Ψs : Effects Rs}
         -> Unionᵉ Ψs rs A rs′ -> Unionᵉ (Ψ , Ψs) (r , rs) A (λ x -> r , rs′ x)

data Unionʰᵉ : HigherEffects -> HigherEffect where
  hereʰᵉ   : ∀ {Φs Rs rs A rs′} {Φ : HigherEffect} {Ψs : Effects Rs}
           -> Φ {Rs} Ψs rs A rs′ -> Unionʰᵉ (Φ ∷ Φs) Ψs rs A rs′
  thereʰᵉ  : ∀ {Φs Rs rs A rs′} {Φ : HigherEffect} {Ψs : Effects Rs}
           -> Unionʰᵉ Φs Ψs rs A rs′ -> Unionʰᵉ (Φ ∷ Φs) Ψs rs A rs′

--------------------

data IFreer {R : Set} (Ψ : Effect R) : Effect R where
  return : ∀ {B r′} y -> IFreer Ψ (r′ y) B r′
  call   : ∀ {r A r′ B r′′} -> Ψ r A r′ -> (∀ x -> IFreer Ψ (r′ x) B r′′) -> IFreer Ψ r B r′′

liftᶠ : ∀ {R Ψ r A r′} -> Ψ r A r′ -> IFreer {R} Ψ r A r′
liftᶠ a = call a return

_>>=_ : ∀ {R Ψ r B r′ C r′′}
      -> IFreer {R} Ψ r B r′ -> (∀ y -> IFreer Ψ (r′ y) C r′′) -> IFreer Ψ r C r′′
return y >>= g = g y
call a f >>= g = call a λ x -> f x >>= g

_>>_ : ∀ {R Ψ r₁ B r₂ C r′′}
     -> IFreer {R} Ψ r₁ B (const r₂) -> IFreer Ψ r₂ C r′′ -> IFreer Ψ r₁ C r′′
b >> c = b >>= const c

_<$>_ : ∀ {R Ψ r₁ B r₂ C} -> (B -> C) -> IFreer {R} Ψ r₁ B (const r₂) -> IFreer Ψ r₁ C (const r₂)
g <$> b = b >>= return ∘ g

_<*>_ : ∀ {R Ψ r₁ B r₂ C r₃}
      -> IFreer {R} Ψ r₁ (B -> C) (const r₂)
      -> IFreer {R} Ψ r₂  B       (const r₃)
      -> IFreer {R} Ψ r₁  C       (const r₃)
h <*> b = h >>= _<$> b

--------------------

EffOver : HigherEffects -> HigherEffect
EffOver Φs Ψs = IFreer (Unionʰᵉ (Unionᵉ ∷ Φs) Ψs)

inj′ : ∀ {R} {Ψ : Effect R} {r A r′ Rs rs} {Ψs : Effects Rs}
     -> (p : Ψ , r ∈² Ψs , rs) -> Ψ r A r′ -> Unionᵉ Ψs rs A (λ x -> replace₁ (r′ x) (un∈ʳ p))
inj′ {Rs = []}     ()
inj′ {Rs = _ ∷ _} (inj₁ (refl , hrefl , hrefl)) = hereᵉ
inj′ {Rs = _ ∷ _} (inj₂  p)                     = thereᵉ ∘ inj′ p

inj : ∀ {R} {Ψ : Effect R} {r A Rs rs} {Ψs : Effects Rs}
    -> Ψ , r ∈² Ψs , rs -> Ψ r A (const r) -> Unionᵉ Ψs rs A (const rs)
inj {Rs = []}     ()
inj {Rs = _ ∷ _} (inj₁ (refl , hrefl , hrefl)) = hereᵉ
inj {Rs = _ ∷ _} (inj₂  p)                     = thereᵉ ∘ inj p

invoke′ : ∀ {Φs R} {Ψ : Effect R} {r A r′ Rs rs} {Ψs : Effects Rs} {{p : Ψ , r ∈² Ψs , rs}}
        -> Ψ r A r′ -> EffOver Φs Ψs rs A _
invoke′ {{p}} = liftᶠ ∘ hereʰᵉ ∘ inj′ p

invoke : ∀ {Φs R} {Ψ : Effect R} {r A Rs rs} {Ψs : Effects Rs} {{p : Ψ , r ∈² Ψs , rs}}
       -> Ψ r A (const r) -> EffOver Φs Ψs rs A _
invoke {{p}} = liftᶠ ∘ hereʰᵉ ∘ inj p

invoke₀ : ∀ {Φs R} {Ψ : Effect R} {r A r′ Rs rs} {Ψs : Effects Rs}
        -> Ψ r A r′ -> EffOver Φs (Ψ , Ψs) (r , rs) A _
invoke₀ {Φs} {Ψ = Ψ} = invoke′ {Φs} {Ψ = Ψ}

hinj : ∀ {Φs Φ Rs rs A rs′} {Ψs : Effects Rs}
     -> Φ ∈ Φs -> Φ Ψs rs A rs′ -> Unionʰᵉ Φs Ψs rs A rs′
hinj {[]}      ()
hinj {Ξ ∷ Φs} (inj₁ refl) = hereʰᵉ
hinj {Ξ ∷ Φs} (inj₂ p)    = thereʰᵉ ∘ hinj p

hinvoke : ∀ {Φs Φ Rs rs A rs′} {Ψs : Effects Rs} {{p : Φ ∈ Φs}}
        -> Φ Ψs rs A rs′ -> EffOver Φs Ψs rs A rs′
hinvoke {{p}} = liftᶠ ∘ thereʰᵉ ∘ hinj p

Eff : HigherEffect
Eff = EffOver []

runEff : ∀ {A} -> Eff tt tt A (const tt) -> A
runEff (return x)            = x
runEff (call (hereʰᵉ  ()) k)
runEff (call (thereʰᵉ ()) k)

runEffM : ∀ {Rs rs A rs′} {M : Set -> Set} {Ψs : Effects Rs}
        -> (∀ {A} -> A -> M A)
        -> (∀ {A B} -> M A -> (A -> M B) -> M B)
        -> (∀ {r A r′} -> Unionᵉ Ψs r A r′ -> M A)
        -> Eff Ψs rs A rs′
        -> M A
runEffM ret bind h (return x)            = ret x
runEffM ret bind h (call (hereʰᵉ  a ) k) = bind (h a) (λ x -> runEffM ret bind h (k x))
runEffM ret bind h (call (thereʰᵉ ()) k)
