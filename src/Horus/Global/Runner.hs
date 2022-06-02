module Horus.Global.Runner (interpret, runImplT, run) where

import Control.Monad.Except (ExceptT, MonadError, liftEither, runExceptT, throwError)
import Control.Monad.Trans (MonadTrans (..))
import Control.Monad.Trans.Free.Church (iterTM)
import Data.Functor.Identity (Identity (..))
import Data.Text (Text)

import qualified Horus.CFGBuild.Runner as CFGBuild (interpret, runImplT)
import Horus.Global (GlobalF (..), GlobalT)

newtype ImplT m a = ImplT (ExceptT Text m a)
  deriving newtype (Functor, Applicative, Monad, MonadError Text)

instance MonadTrans ImplT where
  lift m = ImplT (lift m)

interpret :: forall m a. Monad m => GlobalT m a -> ImplT m a
interpret = iterTM exec
 where
  exec :: GlobalF m (ImplT m a) -> ImplT m a
  exec (RunCFGBuildT builder cont) = do
    mCFG <- lift (CFGBuild.runImplT (CFGBuild.interpret builder))
    liftEither mCFG >>= cont
  exec (Throw t) = throwError t

runImplT :: ImplT m a -> m (Either Text a)
runImplT (ImplT m) = runExceptT m

runImpl :: ImplT Identity a -> Either Text a
runImpl = runIdentity . runImplT

run :: GlobalT Identity a -> Either Text a
run = runImpl . interpret