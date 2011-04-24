module VL.Language.Parser (parse) where

import VL.Language.Common

import VL.Language.Scalar (Scalar, ScalarEnvironment)
import qualified VL.Language.Scalar as Scalar

import VL.Language.Syntax

import qualified VL.Language.Environment as Environment

import VL.Language.Token (Token)
import qualified VL.Language.Token as Token

import Text.Parsec.Prim       hiding (many, (<|>), State, token, parse)
import Text.Parsec.String     ()
import Text.Parsec.Combinator (between)

import Control.Applicative
import Control.Monad.State
import Control.Arrow

-- A custom parser type that carries around additional state used for
-- constant conversion.  The state consists of a scalar environment
-- and an integer count that is used to generate unique variable
-- names.
type Parser = ParsecT [Token] () (State (ScalarEnvironment, Int))

-- Accepts a token @t@ with the result @x@ when @test t@ is @Just x@.
-- Like @token@ from Text.Parsec.Prim, but uses the default token
-- pretty-printing function and ignores the position info.
token :: (Token -> Maybe a) -> Parser a
token test = tokenPrim show (\pos _ _ -> pos) test

-- Accepts a token @t@ with the result @k@ when @t@ is the identifier
-- @k@.
symbol :: String -> Parser String
symbol k = token maybeSymbol
    where
      maybeSymbol (Token.Identifier n)
	  | k == n    = Just k
	  | otherwise = Nothing
      maybeSymbol _   = Nothing

-- Accepts the token @t@ with the result @t@.
literal :: Token -> Parser Token
literal t = token maybeLiteral
    where
      maybeLiteral x
	  | x == t    = Just x
	  | otherwise = Nothing

lparen, rparen :: Parser Token
lparen = literal Token.LParen
rparen = literal Token.RParen

-- Accepts a token @t@ with the result @n@ when @t@ is the identifier
-- @n@ that is not a reserved keyword.
identifier :: Parser Name
identifier = token maybeIdentifier
    where
      maybeIdentifier (Token.Identifier x)
	  | x `notElem` keywords = Just x
	  | otherwise            = Nothing
      maybeIdentifier _          = Nothing

-- The list of reserved keywords.
keywords :: [String]
keywords = [ "lambda"
	   , "cons"
	   , "list"
	   , "cons*"
	   , "if"
	   , "or"
	   , "and"
	   , "not"
	   , "cond"
	   , "let"
	   , "letrec"
	   ]

parseVariable :: Parser SurfaceSyntax
parseVariable = mkVariable <$> identifier

parseConstant :: Parser SurfaceSyntax
parseConstant = do s <- try parseEmptyList <|> token maybeConstant
		   (env, i) <- get
		   -- (), #t, #f are always converted to the same
		   -- global names "#:nil", "#:true", "#:false".
		   let x = case s of
			     Scalar.Nil           -> nil
			     Scalar.Boolean True  -> true
			     Scalar.Boolean False -> false
			     Scalar.Real _        -> "#:real-" ++ show i
		   put (Environment.update x s env, succ i)
		   return (mkVariable x)
    where
      maybeConstant (Token.Boolean b) = Just (Scalar.Boolean b)
      maybeConstant (Token.Real    r) = Just (Scalar.Real    r)
      maybeConstant _                 = Nothing

parseEmptyList :: Parser Scalar
parseEmptyList = Scalar.Nil <$ (lparen >> rparen)

-- Helper combinators and aliases for better readability.
special :: String -> Parser a -> Parser a
special name expr = symbol name *> expr

parens :: Parser a -> Parser a
parens = between lparen rparen

listOf :: Parser a -> Parser [a]
listOf p = parens (many p)

formals :: Parser [Name]
formals = listOf identifier

body :: Parser SurfaceSyntax
body = expression

-- Expression parsers.
parseLambda
    = special "lambda"  $ liftA2 mkLambdaManyArgs formals body
parseCons
    = special "cons"    $ liftA2 mkCons expression expression
parseList
    = special "list"    $ liftA  mkList (many expression)
parseConsStar
    = special "cons*"   $ liftA  mkConsStar (many expression)
parseIf
    = special "if"      $ liftA3 mkIf predicate consequent alternate
    where
      predicate  = expression
      consequent = expression
      alternate  = expression
parseOr
    = special "or"      $ liftA  mkOr (many expression)
parseAnd
    = special "and"     $ liftA  mkAnd (many expression)
parseNot
    = special "not"     $ liftA  mkNot expression
parseCond
    = special "cond"    $ liftA  mkCond clauses
    where
      clauses  = many clause
      clause   = parens $ liftA2 (,) test expression
      test     = expression
parseLet
    = special "let"     $ liftA2 mkLet bindings body
    where
      bindings = listOf binding
      binding  = parens $ liftA2 (,) identifier expression
parseLetrec
    = special "letrec"  $ liftA2 mkLetrecManyArgs bindings body
    where
      bindings = listOf binding
      binding  = parens $ liftA3 (,,) identifier formals body

parseApplication = liftA2 mkApplicationManyArgs expression (many expression)

expression :: Parser SurfaceSyntax
expression = atom <|> list
    where
      atom = parseVariable <|> parseConstant
      list = parens $
		 try parseLambda
	     <|> try parseCons
	     <|> try parseList
	     <|> try parseConsStar
	     <|> try parseIf
	     <|> try parseOr
	     <|> try parseAnd
	     <|> try parseNot
	     <|> try parseCond
	     <|> try parseLet
	     <|> try parseLetrec
	     <|> parseApplication

parse :: String -> (SurfaceSyntax, ScalarEnvironment)
parse = ((either (\_ -> error "parse error") id) *** fst)
      . flip runState (initialEnvironment, 0)
      . runParserT expression () ""
      . Token.scan
    where
      initialEnvironment
	  = Environment.fromList
	    [ (nil,   Scalar.Nil          )
	    , (true,  Scalar.Boolean True )
	    , (false, Scalar.Boolean False)
	    ]