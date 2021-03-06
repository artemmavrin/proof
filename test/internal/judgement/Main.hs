{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Main where

import AutoProof
  ( Formula (And, Iff, Imp, Lit, Not, Or, Var),
    Judgement,
    (|-),
  )
import qualified Test.Hspec as H
import qualified Test.QuickCheck as QC

main :: IO ()
main = H.hspec $ do
  H.describe "instance Eq (Judgement a)" $ do
    assertEqReflexive
    assertEqSymmetric
    assertEqTransitive
  H.describe "instance Ord (Judgement a)" $ do
    assertOrdReflexive
    assertOrdAntisymmetric
    assertOrdTransitive
    assertOrdConsistent
    assertOrdConsistentStrict
    assertOrdEquality
    assertOrdStrictness
  H.describe "instance Show (Judgement a), Read (Judgement a)" $ do
    assertReadShow

-- Generation of random formulas for testing

formula :: Int -> QC.Gen (Formula Int)
formula n
  | n == 0 = QC.oneof [literal, variable]
  | otherwise = QC.oneof formulas
  where
    formulas = [literal, variable, negation, implication, disjunction, conjunction, equivalence]
    literal = Lit <$> QC.arbitrary
    variable = Var <$> QC.chooseInt (0, 9)
    negation = Not <$> subformula
    implication = Imp <$> subformula <*> subformula
    disjunction = Or <$> subformula <*> subformula
    conjunction = And <$> subformula <*> subformula
    equivalence = Iff <$> subformula <*> subformula
    subformula = formula $ n `div` 2

instance QC.Arbitrary (Formula Int) where
  arbitrary = QC.sized formula

instance QC.Arbitrary (Judgement Int) where
  arbitrary = (|-) <$> QC.listOf QC.arbitrary <*> QC.arbitrary

-- Properties to be tested

eqReflexive :: Eq a => a -> Bool
eqReflexive x = x == x

eqSymmetric :: Eq a => a -> a -> Bool
eqSymmetric x y = (x == y) == (y == x)

eqTransitive :: Eq a => a -> a -> a -> Bool
eqTransitive x y z = if x == y && y == z then x == z else True

ordReflexive :: Ord a => a -> Bool
ordReflexive x = x <= x

ordAntisymmetric :: Ord a => a -> a -> Bool
ordAntisymmetric x y = (x <= y && y <= x) == (x == y)

ordTransitive :: Ord a => a -> a -> a -> Bool
ordTransitive x y z = if x <= y && y <= z then x <= z else True

ordConsistent :: Ord a => a -> a -> Bool
ordConsistent x y = (x <= y) == (y >= x)

ordConsistentStrict :: Ord a => a -> a -> Bool
ordConsistentStrict x y = (x < y) == (y > x)

ordEquality :: Ord a => a -> a -> Bool
ordEquality x y = (x == y) == (compare x y == EQ)

ordStrictness :: Ord a => a -> a -> Bool
ordStrictness x y = (x < y) == (x <= y && x /= y)

readShow :: Int -> Judgement Int -> Bool
readShow d x = (x, "") `elem` readsPrec d (showsPrec d x "")

-- Testable assertions

makeAssertion :: QC.Testable p => String -> Int -> p -> H.SpecWith ()
makeAssertion label maxS prop = H.it label $ QC.withMaxSuccess maxS prop

assertEqReflexive :: H.SpecWith ()
assertEqReflexive =
  makeAssertion
    "reflexive: p == p"
    100
    (eqReflexive :: Judgement Int -> Bool)

assertEqSymmetric :: H.SpecWith ()
assertEqSymmetric =
  makeAssertion
    "symmetric: p == q if and only if q == p"
    100
    (eqSymmetric :: Judgement Int -> Judgement Int -> Bool)

assertEqTransitive :: H.SpecWith ()
assertEqTransitive =
  makeAssertion
    "transitive: if p == q and q == r then p == r"
    100
    (eqTransitive :: Judgement Int -> Judgement Int -> Judgement Int -> Bool)

assertOrdReflexive :: H.SpecWith ()
assertOrdReflexive =
  makeAssertion
    "reflexive: p <= p"
    100
    (ordReflexive :: Judgement Int -> Bool)

assertOrdAntisymmetric :: H.SpecWith ()
assertOrdAntisymmetric =
  makeAssertion
    "antisymmetric: if p <= q and q <= p then p == q"
    100
    (ordAntisymmetric :: Judgement Int -> Judgement Int -> Bool)

assertOrdTransitive :: H.SpecWith ()
assertOrdTransitive =
  makeAssertion
    "transitive: if p <= q and q <= r then p <= r"
    100
    (ordTransitive :: Judgement Int -> Judgement Int -> Judgement Int -> Bool)

assertOrdConsistent :: H.SpecWith ()
assertOrdConsistent =
  makeAssertion
    "consistency: p <= q if and only if q >= p"
    100
    (ordConsistent :: Judgement Int -> Judgement Int -> Bool)

assertOrdConsistentStrict :: H.SpecWith ()
assertOrdConsistentStrict =
  makeAssertion
    "consistency (strict): p < q if and only if q > p"
    100
    (ordConsistentStrict :: Judgement Int -> Judgement Int -> Bool)

assertOrdEquality :: H.SpecWith ()
assertOrdEquality =
  makeAssertion
    "equality: p == q if and only if compare p q == EQ"
    100
    (ordEquality :: Judgement Int -> Judgement Int -> Bool)

assertOrdStrictness :: H.SpecWith ()
assertOrdStrictness =
  makeAssertion
    "strict inequality: p < q if and only if p <= q and p /= q"
    100
    (ordStrictness :: Judgement Int -> Judgement Int -> Bool)

assertReadShow :: H.SpecWith ()
assertReadShow =
  makeAssertion
    "(x,\"\") is an element of (readsPrec d (showsPrec d x \"\"))"
    1000
    readShow
