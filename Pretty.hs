{-# LANGUAGE TypeSynonymInstances #-}
module VL.Pretty
    ( Pretty
    , pp
    , render
    )
    where

import VL.Common
import VL.Scalar
import VL.Expression
import VL.Environment (Environment)
import qualified VL.Environment as Environment (bindings)

import VL.ConcreteValue (ConcreteValue (..))
import VL.AbstractValue (AbstractValue (..))

import VL.AbstractAnalysis (AbstractAnalysis)
import qualified VL.AbstractAnalysis as Analysis (toList)

import Text.PrettyPrint

class Pretty a where
    pp :: a -> Doc

instance Pretty Name where
    pp = text

instance Pretty binder => Pretty (Expression binder) where
    pp (Variable x) = pp x
    pp (Lambda x b)
        = parens $ hang (text "lambda" <+> parens (pp x)) 1 (pp b)
    pp (Application e1 e2)
        = parens $ sep [pp e1, pp e2]
    pp (Cons e1 e2)
        = parens $ sep [text "cons", pp e1, pp e2]
    pp (Letrec local_defs body)
        = parens $ sep [ text "letrec"
                       , ppLocalDefinitions local_defs
                       , pp body
                       ]
        where
          ppLocalDefinitions = parens . sep . map ppLocalDefinition
          ppLocalDefinition (v, u, e) = parens $ sep [ text v
                                                     , parens (pp u)
                                                     , pp e
                                                     ]

instance Pretty Scalar where
    pp Nil             = parens empty
    pp (Boolean True)  = text "#t"
    pp (Boolean False) = text "#f"
    pp (Real r)        = float r
    pp (Primitive p)   = pp p

instance Pretty Primitive where
    pp Car    = prim "car"
    pp Cdr    = prim "cdr"
    pp Add    = prim "+"
    pp Sub    = prim "-"
    pp Mul    = prim "*"
    pp Div    = prim "/"
    pp Eql    = prim "=="
    pp Neq    = prim "/="
    pp LTh    = prim "<"
    pp LEq    = prim "<="
    pp GTh    = prim ">"
    pp GEq    = prim ">="
    pp Exp    = prim "exp"
    pp Log    = prim "log"
    pp Pow    = prim "**"
    pp Sin    = prim "sin"
    pp Cos    = prim "cos"
    pp Tan    = prim "tan"
    pp Sqrt   = prim "sqrt"
    pp Asin   = prim "asin"
    pp Acos   = prim "acos"
    pp Atan   = prim "atan"
    pp Sinh   = prim "sinh"
    pp Cosh   = prim "cosh"
    pp Tanh   = prim "tanh"
    pp Asinh  = prim "asinh"
    pp Acosh  = prim "acosh"
    pp Atanh  = prim "atanh"
    pp Neg    = prim "negate"
    pp IfProc = prim "if-procedure"
    pp IsPair = prim "pair?"

internal :: String -> Doc -> Doc
internal name contents = text "#[" <> sep [text name, contents] <> char ']'

prim :: String -> Doc
prim = internal "primitive" . text

instance Pretty val => Pretty (Environment val) where
    pp = parens . sep . map ppBinding . Environment.bindings
        where
          ppBinding (x, v) = ppPair x v

ppClosure :: Pretty val => Environment val -> Name -> CoreExpression -> Doc
ppClosure env x b = internal "closure" $ pp env $+$ pp (Lambda x b)

ppPair :: (Pretty a, Pretty b) => a -> b -> Doc
ppPair x y = parens $ sep [pp x, dot, pp y]

instance Pretty ConcreteValue where
    pp (ConcreteScalar s)        = pp s
    pp (ConcreteClosure env x b) = ppClosure env x b
    pp (ConcretePair v1 v2)      = ppPair v1 v2

instance Pretty AbstractValue where
    pp (AbstractScalar s)        = pp s
    pp AbstractBoolean           = text "B"
    pp AbstractReal              = text "R"
    pp AbstractTop               = text "T"
    pp (AbstractClosure env x b) = ppClosure env x b
    pp (AbstractPair v1 v2)      = ppPair v1 v2

instance Pretty AbstractAnalysis where
    pp analysis = internal "analysis" bindings
        where
          bindings = vcat
                   . punctuate newline
                   . map ppBinding
                   . Analysis.toList
                   $ analysis
          ppBinding ((e, env), v) = sep [ ppPair e env
                                        , text "==>"
                                        , pp v
                                        ]

dot, newline :: Doc
dot     = char '.'
newline = char '\n'
