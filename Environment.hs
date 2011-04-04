module VL.Environment
    ( Environment
    , map
    , empty
    , union
    , domain
    , lookup
    , insert
    , update
    , bindings
    , restrict
    , fromList
    , singleton
    )
    where

import VL.Common

import Prelude hiding (map, lookup)
import qualified Data.List as List

import Data.Set (Set)
import qualified Data.Set as Set

import Control.Arrow (second)

newtype Environment val
    = Environment { bindings :: [(Name, val)] } deriving (Eq, Ord, Show)

empty :: Environment val
empty = Environment []

union :: Eq val => Environment val -> Environment val -> Environment val
union env1 env2 = Environment (bindings env1 `List.union` bindings env2)

domain :: Environment val -> [Name]
domain env = [x | (x, v) <- bindings env]

lookup :: Name -> Environment val -> val
lookup x env
    = fromMaybe (error msg) (List.lookup x (bindings env))
      where
        msg = "Unbound variable: " ++ x

insert :: Name -> val -> Environment val -> Environment val
insert x v env = Environment ((x, v) : bindings env)

update :: Name -> val -> Environment val -> Environment val
update x v env = maybe (insert x v env) (const env) (List.lookup x (bindings env))

restrict :: Set Name -> Environment val -> Environment val
restrict set env = Environment [ (x, v)
                               | (x, v) <- bindings env
                               , x `Set.member` set
                               ]

fromList :: [(Name, val)] -> Environment val
fromList = Environment

singleton :: Name -> val -> Environment val
singleton x v = Environment [(x, v)]

map :: (val1 -> val2) -> Environment val1 -> Environment val2
map f = Environment . List.map (second f) . bindings
