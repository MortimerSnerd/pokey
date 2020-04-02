type
  ChunkType* {.size: sizeof(int16).} = enum
    ## Central list of chunk types so we don't accidentally reuse 
    ## one.  Size to convert the ``Chunk.kind`` field without
    ## truncation.  Do not reorder these, or it will break
    ## existing files.  Only add to the end.
    ctBlocksetSys, 
    ctBlockset, 
    ctBlockfile
