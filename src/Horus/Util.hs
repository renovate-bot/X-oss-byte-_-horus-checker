{-# LANGUAGE ExistentialQuantification #-}

module Horus.Util
  ( fieldPrime
  , whenJust
  , safeLast
  , Box (..)
  , topmostStepFT
  , appendList
  )
where

import Control.Monad.Trans.Free.Church (FT (..))
import Data.List.NonEmpty (NonEmpty (..))

fieldPrime :: Integer
fieldPrime = 2 ^ (251 :: Int) + 17 * 2 ^ (192 :: Int) + 1

whenJust :: Applicative f => Maybe a -> (a -> f ()) -> f ()
whenJust Nothing _ = pure ()
whenJust (Just a) f = f a

safeLast :: [a] -> Maybe a
safeLast [] = Nothing
safeLast l = Just (last l)

data Box f = forall a. Box {unBox :: f a}

topmostStepFT :: Applicative m => FT f m a -> m (Maybe (Box f))
topmostStepFT ft = runFT ft (const (pure Nothing)) (\_ step -> pure (Just (Box step)))

appendList :: NonEmpty a -> [a] -> NonEmpty a
appendList (x :| xs) ys = x :| xs <> ys