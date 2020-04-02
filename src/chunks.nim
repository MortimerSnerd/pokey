## Typed chunks saved or restored from a stream. 
## Not writing a len for chunks to avoid the issues you
## get with IFF files when it's hard to calculate the len
## of a chunk before writing it.  This also makes Chunks
## agnostic to the idea of Chunks being nestable.
##
## Also contains utility functions for writing common
## things, like counted strings, arrays.
import
  chunktypes, hashes, streams, strformat

type
  Chunk* = object
    kind*: ChunkType
    version*: int16  ## Identifier meaningful only for the caller.
    cksum: Hash ## Checksum for just the header.

  BadChunk* = object of CatchableError

  SerFn*[T] = proc (s: Stream; x: T) {.nimcall.}
    ## Standard sig for a serialization function.  Assumed to be able to 
    ## throw anything.

  DesFn*[T] = proc (s: Stream; x: var T) {.nimcall.}
    ## Standard sig for a deserialization function.  Assumed to be able to 
    ## throw anything.

proc expect*(ct: ChunkType; ch: Chunk) = 
    ## Raises BadChunk if the ``ct`` doesn't match ``ch.kind``.
    if ct != ch.kind:
      raise newException(BadChunk, &"Expecting {ct} but got {ch}")

proc cksum(c: Chunk) : Hash = 
  ## For now, we're being cheesy and just using a hash
  ## for the checksum, which it probably sufficient.
  result = result !& hash(ord(c.kind))
  result = result !& hash(c.version)
  result = !$result

proc read*(s: Stream; result: var Chunk) = 
  ## Reads the next chunk into ``result``.  In addition
  ## to the usual IOError's, it can also raise a 
  ## BadChunk if the checksum of a chunk doesn't match.
  if readData(s, addr result, sizeof(result)) != sizeof(result):
    raise newException(IOError, "Unexpected EOF reading Chunk")

  let cs = cksum(result)
  if cs != result.cksum:
    raise newException(BadChunk, "Corrupted chunk.")

proc read*(s: Stream; result: var Chunk; wanted: ChunkType) = 
  read(s, result)
  expect(wanted, result)

proc write*(s: Stream; c: Chunk) = 
  ## Writes a chunk to the stream.
  var mc = c
  mc.cksum = cksum(c)
  write(s, mc)

proc writeSeq*[T](s: Stream; arr: var openarray[T]; serFn: SerFn[T] = nil) = 
  ## Writes an array of items to the stream.  If ``serFn`` is provided, 
  ## it will be called for each array item, otherwise the array is stored
  ## as raw bytes.
  let numit = len(arr)
  write(s, numit)
  if numit > 0:
    if serFn == nil:
      writeData(s, addr arr[0], sizeof(T) * numit)
    else:
      for i in 0..<numit:
        serFn(s, arr[i])

proc readSeq*[T](s: Stream; arr: var seq[T]; desFn: DesFn[T] = nil) = 
  ## Reads an array of items from the stream.  If ``desFn`` is provided, 
  ## it will be called for each array item, otherwise the array is 
  ## read as raw bytes.
  var alen: int
  read(s, alen)
  if alen < 0:
    raise newException(IOError, "Bad seek? Negative array size")

  setLen(arr, alen)
  if alen > 0:
    if desFn == nil:
      let expected = sizeof(T) * alen
      let got = readData(s, addr arr[0], expected)

      if expected != got:
        raise newException(BadChunk, "Unexpected EOF reading seq")
    else:
      for i in 0..<alen:
        desFn(s, arr[i])
