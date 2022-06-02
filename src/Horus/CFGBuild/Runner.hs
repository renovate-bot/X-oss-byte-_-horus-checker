module Horus.CFGBuild.Runner
  ( CFG (..)
  , interpret
  , runImplT
  , cfgArcs
  )
where

import Control.Monad.Except (ExceptT, MonadError, runExceptT, throwError)
import Control.Monad.State (MonadState, StateT, runStateT)
import Control.Monad.Trans (MonadTrans (..))
import Control.Monad.Trans.Free.Church (iterTM)
import Data.List (union)
import Data.Map (Map)
import qualified Data.Map as Map (empty)
import Data.Text (Text)
import Lens.Micro (Lens', at, (&), (^.), _Just)
import Lens.Micro.GHC ()
import Lens.Micro.Mtl ((%=))

import Horus.CFGBuild (CFGBuildF (..), CFGBuildT (..), Label)
import Horus.Instruction (Instruction)
import SimpleSMT.Typed (TSExpr)

newtype ImplT m a = ImplT (ExceptT Text (StateT CFG m) a)
  deriving newtype (Functor, Applicative, Monad, MonadState CFG, MonadError Text)

instance MonadTrans ImplT where
  lift m = ImplT (lift . lift $ m)

data CFG = CFG
  { cfg_vertices :: [Label]
  , cfg_arcs :: Map Label [(Label, [Instruction], TSExpr Bool)]
  , cfg_assertions :: Map Label [TSExpr Bool]
  }
  deriving (Show)

emptyCFG :: CFG
emptyCFG = CFG [] Map.empty Map.empty

cfgVertices :: Lens' CFG [Label]
cfgVertices lMod g = fmap (\x -> g{cfg_vertices = x}) (lMod (cfg_vertices g))

cfgArcs :: Lens' CFG (Map Label [(Label, [Instruction], TSExpr Bool)])
cfgArcs lMod g = fmap (\x -> g{cfg_arcs = x}) (lMod (cfg_arcs g))

cfgAssertions :: Lens' CFG (Map Label [TSExpr Bool])
cfgAssertions lMod g = fmap (\x -> g{cfg_assertions = x}) (lMod (cfg_assertions g))

interpret :: Monad m => CFGBuildT m a -> ImplT m a
interpret = iterTM exec . runCFGBuildT
 where
  exec (AddVertex l cont) = cfgVertices %= ([l] `union`) >> cont
  exec (AddArc lFrom lTo insts test cont) = cfgArcs . at lFrom %= doAdd >> cont
   where
    doAdd mArcs = Just ((lTo, insts, test) : mArcs ^. _Just)
  exec (AddAssertion l assertion cont) = cfgAssertions . at l %= doAdd >> cont
   where
    doAdd mAssertions = Just (assertion : mAssertions ^. _Just)
  exec (Throw t) = throwError t

runImplT :: Monad m => ImplT m a -> m (Either Text CFG)
runImplT (ImplT m) = do
  (r, cfg) <- runExceptT m & flip runStateT emptyCFG
  pure (fmap (const cfg) r)