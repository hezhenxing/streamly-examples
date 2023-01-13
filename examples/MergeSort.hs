module Main
    ( main
    , sortMergeCombined
    , sortMergeChunks
    )
where

import Control.Monad (void)
import Data.Function ((&))
import Streamly.Data.Array (Array)
import Streamly.Data.Stream (Stream)

import qualified Streamly.Data.Array as Array
import qualified Streamly.Data.Fold as Fold
import qualified Streamly.Data.Stream.Prelude as Stream
import qualified Streamly.Internal.Data.Stream as Stream

input :: [Int]
input = [1000000,999999..1]

chunkSize :: Int
chunkSize = 32*1024

streamChunk :: Array Int -> Stream IO Int
streamChunk =
      Stream.sortBy compare
    . Stream.unfold Array.reader

sortChunk :: Array Int -> IO (Array Int)
sortChunk = Stream.fold Array.write . streamChunk

-------------------------------------------------------------------------------
-- Stream the unsorted chunks and sort, merge those streams.
-------------------------------------------------------------------------------

-- In contrast to sortMergeSeparate this uses much more peak memory because all
-- the streams are open in memory at the same time.
sortMergeCombined :: (Array Int -> Stream IO Int) -> IO ()
sortMergeCombined f =
    Stream.fromList input
        & Stream.arraysOf chunkSize
        & Stream.mergeMapWith (Stream.mergeBy compare) f
        & Stream.fold Fold.drain

-------------------------------------------------------------------------------
-- First create a stream of sorted chunks, then stream sorted chunks and merge
-- the streams
-------------------------------------------------------------------------------

sortMergeSeparate ::
       (   (Array Int -> IO (Array Int))
        -> Stream IO (Array Int)
        -> Stream IO (Array Int)
       )
    -> IO ()
sortMergeSeparate f =
    Stream.fromList input
        & Stream.arraysOf chunkSize
        & f sortChunk
        & Stream.mergeMapWith
            (Stream.mergeBy compare) (Stream.unfold Array.reader)
        & Stream.fold Fold.drain

-------------------------------------------------------------------------------
-- First create a stream of sorted chunks, merge sorted chunks into sorted
-- chunks recursively.
-------------------------------------------------------------------------------

reduce :: Array Int -> Array Int -> IO (Array Int)
reduce arr1 arr2 =
    Stream.mergeBy
        compare
        (Stream.unfold Array.reader arr1)
        (Stream.unfold Array.reader arr2)
        & Stream.fold Array.write

sortMergeChunks ::
       (  (Array Int -> IO (Array Int))
       -> Stream IO (Array Int)
       -> Stream IO (Array Int)
       )
    -> IO ()
sortMergeChunks f =
    Stream.fromList input
        & Stream.arraysOf chunkSize
        & f sortChunk
        & Stream.reduceIterateBfs reduce
        & void

-- | Divide a stream in chunks, sort the chunks and merge them.
main :: IO ()
main = do
    -- Sorted in best performing first order
    sortMergeSeparate (Stream.parMapM id)
    -- sortMergeSeparate Stream.mapM
    -- sortMergeCombined (Stream.parEval id . streamChunk)
    -- sortMergeCombined streamChunk
    -- sortMergeChunks (Stream.parMapM id)
    -- sortMergeChunks Stream.mapM
