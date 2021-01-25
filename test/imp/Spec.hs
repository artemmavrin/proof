import Data.Prop (Sequent, debug, prettySequent)
import Data.Prop.Parser (unsafeParseSequent)
import Data.Prop.Proof.Implication (proveImp)
import Data.Prop.Utils (PrettyPrintable)
import qualified Test.Hspec as H (SpecWith, describe, hspec, it, shouldBe)

main :: IO ()
main = do
  -- Load known provable and unprovable sequents
  provable <- loadSequents "test/imp/examples/provable.sequents"
  unprovable <- loadSequents "test/imp/examples/unprovable.sequents"

  -- Run tests
  H.hspec $
    H.describe "proveImp" $ do
      mapM_ assertProvable provable
      mapM_ assertUnprovable unprovable

loadSequents :: String -> IO [Sequent String]
loadSequents filename = do
  contents <- readFile filename
  return (unsafeParseSequent <$> lines contents)

assertProvable :: (Ord a, PrettyPrintable a, Show a) => Sequent a -> H.SpecWith ()
assertProvable (c, a) =
  H.it ("provable: " ++ prettySequent c a) $
    debug <$> proveImp c a `H.shouldBe` Just (Right ())

assertUnprovable :: (Ord a, PrettyPrintable a, Show a) => Sequent a -> H.SpecWith ()
assertUnprovable (c, a) =
  H.it ("unprovable: " ++ prettySequent c a) $
    proveImp c a `H.shouldBe` Nothing
