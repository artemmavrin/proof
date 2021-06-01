{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Main where

import AutoProof.Classical
  ( Formula (And, Iff, Imp, Lit, Not, Or, Var),
    canonicalCNF,
    isProvable,
    subformulas,
    (|-),
  )
import AutoProof.Classical.CNF (CNF)
import qualified AutoProof.Classical.CNF as CNF (fromFormula)
import qualified Data.Set as Set (member)
import qualified Test.Hspec as H
import qualified Test.QuickCheck as QC

main :: IO ()
main = do
  H.hspec $
    H.describe "CNF" $ do
      checkCanonicalForm
      validateFormulaEntailsCNF
      validateCNFEntailsFormula

arbitraryFormula :: Int -> QC.Gen (Formula Int)
arbitraryFormula n
  | n == 0 = QC.oneof [literal, variable]
  | otherwise = QC.oneof formulas
  where
    literal = Lit <$> QC.arbitrary
    variable = Var <$> QC.chooseInt (0, 2)
    negation = Not <$> subformula
    implication = Imp <$> subformula <*> subformula
    disjunction = Or <$> subformula <*> subformula
    conjunction = And <$> subformula <*> subformula
    equivalence = Iff <$> subformula <*> subformula
    subformula = QC.chooseInt (0, n - 1) >>= arbitraryFormula
    formulas =
      [ literal,
        variable,
        negation,
        implication,
        disjunction,
        conjunction,
        equivalence
      ]

instance QC.Arbitrary (Formula Int) where
  arbitrary = QC.chooseInt (0, 2) >>= arbitraryFormula

timeoutMicroseconds :: Int
timeoutMicroseconds = 60000000 -- One minute

wait :: QC.Testable p => p -> QC.Property
wait = QC.within timeoutMicroseconds

assertFormulaEntailsCNF :: Formula Int -> QC.Property
assertFormulaEntailsCNF a = wait $ isProvable ([a] |- canonicalCNF a)

assertCNFEntailsFormula :: Formula Int -> QC.Property
assertCNFEntailsFormula a = wait $ isProvable ([canonicalCNF a] |- a)

assertCanonicalForm :: Formula Int -> Bool
assertCanonicalForm a =
  noRedundantClauses (CNF.fromFormula a)
    && noTrueOrFalse (canonicalCNF a)

noRedundantClauses :: CNF Int -> Bool
noRedundantClauses = all noLiteralAndItsNegation
  where
    noLiteralAndItsNegation c = not (any (occursWithNegation c) c)
    occursWithNegation c (b, x) = (not b, x) `Set.member` c

noTrueOrFalse :: Ord b => Formula b -> Bool
noTrueOrFalse a =
  a == Lit True || a == Lit False
    || not (Lit True `Set.member` s || Lit False `Set.member` s)
  where
    s = subformulas a

validateFormulaEntailsCNF :: H.SpecWith ()
validateFormulaEntailsCNF =
  H.it "a |- CNF(a)" $
    QC.withMaxSuccess 10000 assertFormulaEntailsCNF

validateCNFEntailsFormula :: H.SpecWith ()
validateCNFEntailsFormula =
  H.it "CNF(a) |- a" $
    QC.withMaxSuccess 10000 assertCNFEntailsFormula

checkCanonicalForm :: H.SpecWith ()
checkCanonicalForm =
  H.it "computed CNFs are in canonical form" $
    QC.withMaxSuccess 10000 assertCanonicalForm
