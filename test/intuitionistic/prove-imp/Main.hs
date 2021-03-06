{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Main where

import AutoProof.Intuitionistic
  ( Formula (Imp, Var),
    Judgement,
    correct,
    hasCut,
    prettyJudgement,
    proveImp,
    (|-),
  )
import AutoProof.Internal.Parser (unsafeParseJudgement)
import Data.Char (isSpace)
import Data.Maybe (fromJust, isJust)
import qualified Test.Hspec as H
import qualified Test.QuickCheck as QC

main :: IO ()
main = do
  -- Load known provable and unprovable sequents
  provable <- loadJudgements "test/data/judgements/intuitionistic-provable-imp.txt"
  unprovable <- loadJudgements "test/data/judgements/intuitionistic-unprovable-imp.txt"

  -- Run tests
  H.hspec $
    H.describe "proveImp" $ do
      mapM_ assertProvable provable
      mapM_ assertUnprovable unprovable
      validateRandomValidProofOfTautology
      validateRandomValidProofOfJudgement

formula :: Int -> QC.Gen (Formula Char)
formula n
  | n == 0 = variable
  | otherwise = QC.oneof [variable, implication]
  where
    variable = Var <$> QC.chooseEnum ('a', 'e')
    implication = Imp <$> subformula <*> subformula
    subformula = formula $ n `div` 2

instance QC.Arbitrary (Formula Char) where
  arbitrary = QC.sized formula

instance QC.Arbitrary (Judgement Char) where
  arbitrary = (|-) <$> (QC.chooseInt (0, 3) >>= QC.vector) <*> QC.arbitrary

loadJudgements :: String -> IO [Judgement String]
loadJudgements filename = do
  contents <- readFile filename
  let strings = lines contents
  let formulaStrings = clean strings
  return (unsafeParseJudgement <$> formulaStrings)
  where
    stripSpace = reverse . dropWhile isSpace . reverse . dropWhile isSpace
    dropComments = takeWhile (/= '#')
    clean = filter (not . null) . map (stripSpace . dropComments)

timeoutMicroseconds :: Int
timeoutMicroseconds = 60000000 -- One minute

wait :: QC.Testable p => p -> QC.Property
wait = QC.within timeoutMicroseconds

assertProvable :: Judgement String -> H.SpecWith ()
assertProvable j =
  H.it ("provable: " ++ prettyJudgement j) $
    wait $ (\p -> correct j p && not (hasCut p)) <$> proveImp j `H.shouldBe` Just True

assertUnprovable :: Judgement String -> H.SpecWith ()
assertUnprovable j =
  H.it ("unprovable: " ++ prettyJudgement j) $
    wait $ proveImp j `H.shouldBe` Nothing

assertValidProofOfTautology :: Formula Char -> QC.Property
assertValidProofOfTautology t = assertValidProofOfJudgement ([] |- t)

assertValidProofOfJudgement :: Judgement Char -> QC.Property
assertValidProofOfJudgement j =
  let mp = proveImp j
   in wait $
        isJust mp
          QC.==> let p = fromJust mp
                  in correct j p && not (hasCut p)

validateRandomValidProofOfTautology :: H.SpecWith ()
validateRandomValidProofOfTautology =
  H.it "trying to prove random implicational tautologies" $
    QC.withMaxSuccess 10000 assertValidProofOfTautology

validateRandomValidProofOfJudgement :: H.SpecWith ()
validateRandomValidProofOfJudgement =
  H.it "trying to prove random implicational judgements" $
    QC.withMaxSuccess 10000 assertValidProofOfJudgement
