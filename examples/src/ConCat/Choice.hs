{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE UndecidableSuperClasses #-}
{-# LANGUAGE ViewPatterns #-}

{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -Wno-unused-imports #-} -- TEMP

-- | Indexed sets of morphisms

module ConCat.Choice where

import Prelude hiding (id,(.),curry,uncurry,const)
import qualified Prelude as P
import GHC.Types (Constraint)

import Control.Newtype (Newtype(..))

import ConCat.Misc ((:*),oops,inNew,inNew2)
import ConCat.Category
import ConCat.AltCat (toCcc,unCcc) -- (reveal,conceal)

-- | Nondeterminism category. Like a set of morphisms all of the same type, but
-- represented as a function whose range is that set. The function's domain is
-- existentially hidden.
data Choice :: (* -> Constraint) -> * -> * -> * where
  Choice :: con p => (p -> a -> b) -> Choice con a b

-- Equivalently,
-- 
-- data Choice con a b = forall p. con p => Choice (p -> a -> b)

onChoice :: forall con a b q.
            (forall p. con p => (p -> a -> b) -> q) -> Choice con a b -> q
onChoice h (Choice f) = h f
{-# INLINE onChoice #-}

-- | Deterministic (trivially nondeterministic) arrow
exactly :: con () => (a -> b) -> Choice con a b
exactly f = Choice (\ () -> f)
{-# INLINE exactly #-}

type CartCon con = (con (), OpCon (:*) (Sat con))

-- | Generate any value of type @p@.
chooseC :: forall con p a b. (CartCon con, con p)
        => Choice con (p :* a) b -> Choice con a b
chooseC (Choice (f :: q -> p :* a -> b)) =
  Choice @con (uncurry (curry . f))
    <+ inOp @(:*) @(Sat con) @q @p
{-# INLINE chooseC #-}

--           Choice f  :: Choice con (q :* a) b
--                  f  :: q -> p :* a -> b
--          curry . f  :: q -> p -> a -> b
-- uncurry (curry . f) :: q :* p -> a -> b

-- Equivalently, \ (q,p) a -> f q (p,a)

-- | Generate any value of type @p@.
choose :: forall con p a b. (CartCon con, con p)
       => (p -> a -> b) -> (a -> b)
choose f = unCcc (chooseC @con (toCcc (uncurry f)))
{-# INLINE choose #-}

{--------------------------------------------------------------------
    Category class instances
--------------------------------------------------------------------}

combine :: forall con a b c d e f. CartCon con
        => ((a -> b) -> (c -> d) -> (e -> f))
        -> (Choice con a b -> Choice con c d -> Choice con e f)
combine op (Choice (g :: q -> a -> b)) (Choice (f :: p -> c -> d)) =
  Choice (\ (p,q) -> g q `op` f p)
    <+ inOp @(:*) @(Sat con) @p @q

instance CartCon con => Category (Choice con) where
  type Ok (Choice con) = Ok (->) -- Yes1
  id = exactly id
  (.) = combine (.)
  {-# INLINE (.) #-}

instance CartCon con => ProductCat (Choice con) where
  exl = exactly exl
  exr = exactly exr
  (&&&) = combine (&&&)
  {-# INLINE (&&&) #-}

instance CartCon con => CoproductCat (Choice con) where
  inl = exactly inl
  inr = exactly inr
  (|||) = combine (|||)
  {-# INLINE (|||) #-}

instance CartCon con => DistribCat (Choice con) where
  distl = exactly distl
  distr = exactly distr

instance CartCon con => ClosedCat (Choice con) where
  apply = exactly apply
  curry (Choice f) = Choice (curry . f)
  uncurry (Choice g) = Choice (uncurry . g)

instance CartCon con => TerminalCat (Choice con) where
  it = exactly it

instance CartCon con => ConstCat (Choice con) b where
  const b = exactly (const b)

instance CartCon con => BoolCat (Choice con) where
  notC = exactly notC
  andC = exactly andC
  orC  = exactly orC
  xorC = exactly xorC

instance (Eq a, CartCon con) => EqCat (Choice con) a where
  equal    = exactly equal
  notEqual = exactly notEqual

instance (Ord a, CartCon con) => OrdCat (Choice con) a where
  lessThan           = exactly lessThan
  greaterThan        = exactly greaterThan
  lessThanOrEqual    = exactly lessThanOrEqual
  greaterThanOrEqual = exactly greaterThanOrEqual

instance (Enum a, CartCon con) => EnumCat (Choice con) a where
  succC = exactly succC
  predC = exactly predC

instance (Num a, CartCon con) => NumCat (Choice con) a where
  addC    = exactly addC
  mulC    = exactly mulC
  negateC = exactly negateC
  powIC   = exactly powIC

instance (Integral a, con ()) => IntegralCat (Choice con) a where
  divC = exactly divC
  modC = exactly modC

instance (Fractional a, con ()) => FractionalCat (Choice con) a where
  recipC  = exactly recipC
  divideC = exactly divideC

instance (Floating a, con ()) => FloatingCat (Choice con) a where
  expC = exactly expC
  cosC = exactly cosC
  sinC = exactly sinC

instance (Integral b, RealFrac a, con ()) => RealFracCat (Choice con) a b where
  floorC    = exactly floorC
  ceilingC  = exactly ceilingC
  truncateC = exactly truncateC

instance (Integral a, Num b, con ()) => FromIntegralCat (Choice con) a b where
  fromIntegralC = exactly fromIntegralC

instance (con ()) => BottomCat (Choice con) a b where
  bottomC = exactly bottomC

instance CartCon con => IfCat (Choice con) a where
  ifC = exactly ifC

instance con () => UnknownCat (Choice con) a b where
  unknownC = exactly unknownC

instance (RepCat (->) a r, con ()) => RepCat (Choice con) a r where
  reprC = exactly reprC
  abstC = exactly abstC

instance CartCon con => ArrayCat (Choice con) a b where
  array = exactly array
  arrAt = exactly arrAt

{--------------------------------------------------------------------
    Experiment
--------------------------------------------------------------------}

data OptArg con z = NoArg z | forall p. con p => Arg (p -> z)

newtype Choice' :: (* -> Constraint) -> * -> * -> * where
  Choice' :: OptArg con (a -> b) -> Choice' con a b

instance Newtype (Choice' con a b) where
  type O (Choice' con a b) = OptArg con (a -> b)
  pack o = Choice' o
  unpack (Choice' o) = o

type CartCon' con = OpCon (:*) (Sat con)

-- | Deterministic (trivially nondeterministic) arrow
exactly' :: (a -> b) -> Choice' con a b
exactly' f = Choice' (NoArg f)

-- instance CartCon' con => Category (Choice' con) where
--   id = exactly' id
--   Choice' (NoArg g) . Choice' (NoArg f) = Choice' (NoArg (g . f))
--   Choice' (NoArg g) . Choice' (Arg (f :: p -> a -> b)) =
--     Choice' (Arg (\ p -> g . f p))
--   Choice' (Arg (g :: q -> b -> c)) . Choice' (NoArg f) =
--     Choice' (Arg (\ q -> g q . f))
--   Choice' (Arg (g :: q -> b -> c)) . Choice' (Arg (f :: p -> a -> b)) =
--     Choice' (Arg (\ (p,q) -> g q . f p))
--         <+ inOp @(:*) @(Sat con) @p @q

op1 :: forall con u v. CartCon' con
    => (u -> v) -> (OptArg con u -> OptArg con v)
op1 op (NoArg u) = NoArg (op u)
op1 op (  Arg g) = Arg (op . g)

op1C :: forall con a b c d. CartCon' con
     => ((a -> b) -> (c -> d))
     -> (Choice' con a b -> Choice' con c d)
op1C = inNew . op1

op2 :: forall con u v w. CartCon' con
    => (u -> v -> w) -> (OptArg con u -> OptArg con v -> OptArg con w)
op2 op (NoArg u) (NoArg v) = NoArg (u `op` v)
op2 op (NoArg u) (Arg (f :: p -> v)) = Arg (\ p -> u `op` f p)
op2 op (Arg (g :: q -> u)) (NoArg v) = Arg (\ q -> g q `op` v)
op2 op (Arg (g :: q -> u)) (Arg (f :: p -> v)) =
  Arg (\ (p,q) -> g q `op` f p) <+ inOp @(:*) @(Sat con) @p @q

op2C :: forall con a b c d e f. CartCon' con
     => ((a -> b) -> (c -> d) -> (e -> f))
     -> (Choice' con a b -> Choice' con c d -> Choice' con e f)
op2C = inNew2 . op2

instance CartCon' con => Category (Choice' con) where
  id = exactly' id
  (.) = op2C (.)
  {-# INLINE (.) #-}

instance CartCon' con => ProductCat (Choice' con) where
  exl = exactly' exl
  exr = exactly' exr
  (&&&) = op2C (&&&)
  {-# INLINE (&&&) #-}

instance CartCon' con => CoproductCat (Choice' con) where
  inl = exactly' inl
  inr = exactly' inr
  (|||) = op2C (|||)
  {-# INLINE (|||) #-}

instance CartCon' con => DistribCat (Choice' con) where
  distl = exactly' distl
  distr = exactly' distr

instance CartCon' con => ClosedCat (Choice' con) where
  apply = exactly' apply
  curry = op1C curry
  uncurry = op1C uncurry

instance CartCon' con => BoolCat (Choice' con) where
  notC = exactly' notC
  andC = exactly' andC
  orC  = exactly' orC
  xorC = exactly' xorC

-- ... EqCat, OrdCat, NumCat, ...

-- Other classes

instance (Monoid a, CartCon' con) => Monoid (OptArg con a) where
  mempty = NoArg mempty
  mappend = op2 mappend