-- |
-- Module      : Data.Prop.Proof.Implication
-- Copyright   : (c) Artem Mavrin, 2021
-- License     : BSD3
-- Maintainer  : artemvmavrin@gmail.com
-- Stability   : experimental
-- Portability : POSIX
--
-- Intuitionistic natural deduction proofs in the implicational fragment of
-- propositional logic.
module Data.Prop.Proof.Implication
  ( -- * Proof search
    proveImp,
  )
where

import Data.Prop.Proof.Types (Proof (Ax, ImpElim, ImpIntr))
import Data.Prop.Types (Formula (Imp, Var))
import qualified Data.Set as Set

-- | @(proveImp c a)@ finds an intuitionistic proof of a sequent @c ⊢ a@ in the
-- implicational fragment of propositional logic, if such a proof exists.
--
-- The algorithm is due to Statman; see the following references:
--
-- *  Richard Statman (1979)
--    "Intuitionistic propositional logic is polynomial-space complete."
--    Theoretical Computer Science, Volume 9, Issue 1, pp. 67–72.
--    <https://doi.org/10.1016/0304-3975(79)90006-9 DOI>.
-- *  M.H. Sørensen, P. Urzyczyn (2006)
--    /Lectures on the Curry-Howard isomorphism/.
--    Elsevier. See section 4.2.
-- *  Samuel Mimram (2020)
--    /PROGRAM = PROOF/.
--    See section 2.4.
proveImp :: (Ord a, Foldable t) => t (Formula a) -> Formula a -> Maybe (Proof a)
proveImp context = prove Set.empty (foldr Set.insert Set.empty context)
  where
    -- We search for a proof while maintaining a set @s@ of previously seen
    -- sequents to avoid cycles
    --
    -- Easy case: if there is a proof of c ⊢ a → b, then there must be a proof
    -- of c ⊢ a → b that ends with an inference of the form
    --
    --  c,a ⊢ b
    -- --------- (→I)
    -- c ⊢ a → b
    --
    -- so it suffices to look for a proof of c,a ⊢ b
    prove s c i@(Imp a b) = ImpIntr c i <$> prove s' c' b
      where
        s' = Set.insert (i, c) s
        c' = Set.insert a c

    -- Trickier case: if there is a proof of c ⊢ x, where x is a variable, then
    -- either
    --
    -- (1) x belongs to c, so c ⊢ x is proved via
    --
    -- ----- (Ax)
    -- c ⊢ x
    --
    -- or
    --
    -- (2) there is a sequence a1,...,an of propositional formulas such that
    -- a1 → (a2 → (... an → x)...) belongs to c, and c ⊢ ai for all i=1,...,n.
    -- In this case, one proof of c ⊢ x is
    --
    --                                          ?
    -- ------------------------------- (Ax)  ------
    -- c ⊢ a1 → (a2 → (... an → x)...)       c ⊢ a1          ?
    -- -------------------------------------------- (→E)  ------
    --        c ⊢ a2 → (... an → x)                       c ⊢ a2
    --                                 ...                            ?
    --                                                             ------
    --                             c ⊢ an → x                      c ⊢ an
    -- ------------------------------------------------------------------ (→E)
    --                               c ⊢ x
    --
    -- Actually, case (1) can be thought as the n=0 case of case (2).
    --
    -- The implementation:
    prove s c v@(Var x) =
      if Set.member (v, c) s
        then Nothing -- Already visited current sequent; needed to avoid cycles
        else Set.foldr findImp Nothing c
      where
        -- Save the current sequent so we don't revisit it recursively
        s' = Set.insert (v, c) s

        -- findImp is folded over the context looking for implications ending in
        -- the variable x. When encountering a formula of the form
        -- a1 → (a2 → (... an → x)...), ensure each ai is provable, and, if so,
        -- construct a proof.
        findImp _ p@(Just _) = p -- Already found a proof!
        findImp a Nothing = do
          as <- splitImp a
          construct as v

        -- Given a formula of the form a1 → (a2 → (... an → x)...), extract the
        -- list [an, ..., a2, a1]. For formulas of all other forms, return
        -- nothing.
        splitImp = go []
          where
            go l (Var y) = if x == y then Just l else Nothing
            go l (Imp a b) = go (a : l) b
            go _ _ = undefined -- Non-implicational case

        -- Given a list of formulas [an, ..., a2, a1] from an implication of the
        -- form a1 → (a2 → (... an → x)...), try to prove the ai's, and use the
        -- resulting proofs to construct a proof of x
        construct [] b = Just $ Ax c b
        construct (a : as) b =
          ImpElim c b <$> construct as (Imp a b) <*> prove s' c a

    -- Non-implicational case
    prove _ _ _ = undefined