import qualified Streamly.Prelude as Stream
import qualified Streamly.Internal.Data.Stream.IsStream as Stream
       (chunksOf2, evalStateT)
import qualified Streamly.FileSystem.Handle as FH
import qualified Streamly.Internal.FileSystem.Handle as FH (write2)
import qualified System.IO as FH

import Control.Monad.IO.Class (liftIO)
import Control.Monad.State.Strict (StateT(..), get, put)
import System.Environment (getArgs)
import System.IO (IOMode(..))
import Data.Function ((&))

newHandle :: StateT (Maybe (FH.Handle, Int)) IO FH.Handle
newHandle = do
    old <- get
    idx <- case old of
            Nothing -> return 0
            Just (h, i) -> liftIO (FH.hClose h) >> return (i + 1)
    h <- liftIO $ FH.openFile ("dst-xyz-" ++ show idx ++ ".txt") WriteMode
    put (Just (h, idx))
    return h

-- XXX reduce the input stream to a stream of file names
-- The fold can return the file name/handle after it is done.
-- similarly the files can written to directories and we can generate a stream
-- of directory names.
splitFile :: FH.Handle -> IO ()
splitFile inHandle =
      Stream.unfold FH.read inHandle
    & Stream.liftInner
    & Stream.chunksOf2 (180 * 1024 * 1024) newHandle FH.write2
    & Stream.evalStateT (return Nothing)  -- generate new handle for each iteration
    & Stream.drain

main :: IO ()
main = do
    name <- fmap head getArgs
    src <- FH.openFile name ReadMode
    splitFile src
