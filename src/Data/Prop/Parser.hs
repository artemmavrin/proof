{-# LANGUAGE FlexibleContexts #-}

-- |
-- Module      : Data.Prop.Parser
-- Copyright   : (c) Artem Mavrin, 2021
-- License     : BSD3
-- Maintainer  : artemvmavrin@gmail.com
-- Stability   : experimental
-- Portability : POSIX
--
-- Implements a parser for propositional logic formulas
module Data.Prop.Parser
  ( -- * Safe parsing
    parseFormula,
    parseSequent,

    -- * Unsafe parsing
    unsafeParseFormula,
    unsafeParseSequent,
  )
where

import qualified Data.Set as Set (fromList)
import Data.Functor.Identity (Identity)
import Data.Prop.Types (Formula (Imp, Var), Sequent, Context)
import Text.Parsec.Char (char, oneOf, spaces, string)
import Text.Parsec.Combinator (between, eof, sepBy, sepBy1)
import Text.Parsec.Error (ParseError)
import Text.Parsec.Prim (ParsecT, Stream, many, parse, try, (<|>))

-- | @(parseTerm s)@ parses a string-like value @s@ as a propositional formula,
-- returning a @'Right' a@ on success, where @a@ is the parsed term. Otherwise,
-- @'Left' e@ is returned, where @e@ is a 'ParseError'.
--
-- __Note:__ Parsing is currently only implemented for the implicational
-- fragment.
--
-- __Conventions__
--
-- * Implication is right-associative.
-- * Symbols for implication must be one of @"->"@, @"→"@, @"=>"@, @"⇒"@, or
--   @"⊃"@.
-- * Valid variable names begin with a letter (uppercase or lowercase) or an
--   underscore, and may be followed by a letter, underscore, digit, or single
--   quote (a "prime" symbol).
--
-- ==== __Examples__
--
-- >>> parseFormula "a -> b -> c"
-- Right (Imp (Var "a") (Imp (Var "b") (Var "c")))
parseFormula :: Stream s Identity Char => s -> Either ParseError (Formula String)
parseFormula = parse (formula <* eof) ""

-- | @(parseSequent s)@ parses a string-like value @s@ as a propositional
-- sequent. The context is a (potentially empty) comma-separated list of
-- formulas, the judgement turnstile symbol is either @"|-"@ or @"⊢"@, and the
-- conclusion is another formula.
--
-- ==== __Examples__
--
-- >>> parseSequent "a, a -> b |- b"
-- Right (fromList [Var "a",Imp (Var "a") (Var "b")],Var "b")
parseSequent :: Stream s Identity Char => s -> Either ParseError (Sequent String)
parseSequent = parse (sequent <* eof) ""

-- | @(unsafeParseFormula s)@ parses a string-like value @s@ as a propositional
-- formula, returning the parsed formula on success, and throwing an error on
-- failure.
--
-- ==== __Examples__
--
-- >>> unsafeParseFormula "(a => b) => c"
-- Imp (Imp (Var "a") (Var "b")) (Var "c")
unsafeParseFormula :: Stream s Identity Char => s -> Formula String
unsafeParseFormula = either (error . show) id . parseFormula

-- | @(unsafeParseSequent s)@ parses a string-like value @s@ as a propositional
-- sequent, returning the parsed sequent on success, and throwing an error on
-- failure.
--
-- ==== __Examples__
--
-- >>> unsafeParseSequent "a, b |- a -> b"
-- (fromList [Var "a",Var "b"],Imp (Var "a") (Var "b"))
unsafeParseSequent :: Stream s Identity Char => s -> Sequent String
unsafeParseSequent = either (error . show) id . parseSequent

formula :: Stream s m Char => ParsecT s u m (Formula String)
formula = padded implication

context :: Stream s m Char => ParsecT s u m (Context String)
context = Set.fromList <$> try formula `sepBy` char ','

judgement :: Stream s m Char => ParsecT s u m (Formula String)
judgement = turnstile *> formula

sequent :: Stream s m Char => ParsecT s u m (Sequent String)
sequent = (,) <$> context <*> judgement

implication :: Stream s m Char => ParsecT s u m (Formula String)
implication = foldr1 Imp <$> terms
  where
    term = enclosed formula <|> variable
    terms = term `sepBy1` try rightArrow

variable :: Stream s m Char => ParsecT s u m (Formula String)
variable = Var <$> name
  where
    name = (:) <$> nameStart <*> many nameChar
    nameStart = oneOf $ '_' : ['a' .. 'z'] ++ ['A' .. 'Z']
    nameChar = nameStart <|> oneOf ('\'' : ['0' .. '9'])

-- Ignore space on either side of a parsed string.
padded :: Stream s m Char => ParsecT s u m a -> ParsecT s u m a
padded = between spaces spaces

-- Parse a string surrounded by parentheses.
enclosed :: Stream s m Char => ParsecT s u m a -> ParsecT s u m a
enclosed = between (char '(') (char ')')

-- Parse an implication arrow.
rightArrow :: Stream s m Char => ParsecT s u m String
rightArrow =
  padded $
    try (string "->")
      <|> string "→"
      <|> try (string "=>")
      <|> string "⇒"
      <|> string "⊃"

-- Parse a sequent/judgement turnstile.
turnstile :: Stream s m Char => ParsecT s u m String
turnstile = padded (string "|-" <|> string "⊢")
