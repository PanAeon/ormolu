{-# LANGUAGE LambdaCase #-}

-- | 'OrmoluException' type and surrounding definitions.

module Ormolu.Exception
  ( OrmoluException (..)
  , withPrettyOrmoluExceptions
  )
where

import Control.Exception
import Data.Text (Text)
import Ormolu.Utils (showOutputable)
import System.Exit (ExitCode (..), exitWith)
import System.IO
import qualified GHC

-- | Ormolu exception representing all cases when Ormolu can fail.

data OrmoluException
  = OrmoluCppEnabled
    -- ^ Ormolu does not work with source files that use CPP
  | OrmoluParsingFailed GHC.SrcSpan String
    -- ^ Parsing of original source code failed
  | OrmoluOutputParsingFailed GHC.SrcSpan String
    -- ^ Parsing of formatted source code failed
  | OrmoluASTDiffers [GHC.SrcSpan] String Text
    -- ^ Original and resulting ASTs differ, first argument is the original
    -- source code, second argument is rendered source code
  deriving (Eq, Show)

instance Exception OrmoluException where
  displayException = \case
    OrmoluCppEnabled -> "CPP is not supported"
    OrmoluParsingFailed s e ->
      showParsingErr "Parsing of source code failed:" s e
    OrmoluOutputParsingFailed s e ->
      showParsingErr "Parsing of formatted code failed:" s e ++
        "Please, consider reporting the bug."
    OrmoluASTDiffers ss _ _ -> unlines $
      ["AST of input and AST of formatted code differ."]
      ++ map (\s -> "  at " ++ showOutputable s) ss ++
      ["Please, consider reporting the bug."]

-- | Inside this wrapper 'OrmoluException' will be caught and displayed
-- nicely using 'displayException'.

withPrettyOrmoluExceptions
  :: IO a                       -- ^ Action that may throw the exception
  -> IO a
withPrettyOrmoluExceptions m = m `catch` h
  where
    h :: OrmoluException -> IO a
    h e = do
      hPutStrLn stderr (displayException e)
      exitWith . ExitFailure $
        case e of
          -- Error code 1 is for `error` or `notImplemented`
          OrmoluCppEnabled -> 2
          OrmoluParsingFailed _ _ -> 3
          OrmoluOutputParsingFailed _ _ -> 4
          OrmoluASTDiffers _ _ _ -> 5

----------------------------------------------------------------------------
-- Helpers

-- | Show a parse error.

showParsingErr :: String -> GHC.SrcSpan -> String -> String
showParsingErr msg spn err = unlines
  [ msg
  , showOutputable spn
  , err
  ]
