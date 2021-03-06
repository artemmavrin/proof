-- |
-- Module      : AutoProof.Internal.Classical.Proof
-- Copyright   : (c) Artem Mavrin, 2021
-- License     : BSD3
-- Maintainer  : artemvmavrin@gmail.com
-- Stability   : experimental
-- Portability : POSIX
--
-- Classical proofs in propositional logic.
module AutoProof.Internal.Classical.Proof
  ( -- * Provability checking
    isProvable,
    isTautology,
  )
where

import AutoProof.Internal.Classical.Proof.Provability
  ( isProvable,
    isTautology,
  )
