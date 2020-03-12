import
  geom, glsupport, opengl, sdl2, strformat, verts

type
  Tileset* = object
    ## A tileset for an image divided up into uniform gridDim x gridDim 
    ## tiles.
    file: string ## Relative path to image file that backs this.
    tex: Texture
    gridDim*: Positive ## Tiles are forced to be square, gridDim*gridDim
    tileTopLefts: seq[V2f] ## Topleft texture coordinates for each tile.
    tileTexDim: V2f ## Width and height of a tile in texture coordinates.

  BadTileDims = object of Exception

proc initTileset*(rset: var ResourceSet; file: string, gridDim: Positive) : Tileset {.raises: [GLError, ValueError, BadTileDims, IOError].} = 
  ## Initializes a tileset, raising an exception if the texture can not be loaded, 
  ## or if the image can not be evenly divided up by `gridDim` dimensions.
  var lset: ResourceSet

  result = Tileset(
    file: file,
    tex: loadTexture(lset, file, false, false),
    gridDim: gridDim)

  if result.tex.width <= 0 or result.tex.height <= 0:
    raise newException(BadTileDims, &"Bad texture dims: {result.tex.width}, {result.tex.height}")

  if result.tex.width mod gridDim != 0:
    raise newException(BadTileDims, &"Image dims {result.tex.width}, {result.tex.height} not divisible by {gridDim}")

  applyParameters(result.tex, TextureParams(minFilter: GL_NEAREST, magFilter: GL_NEAREST))
  
  let tw = result.tex.width div gridDim
  let th = result.tex.height div gridDim

  result.tileTexDim = (float32(gridDim) / float32(result.tex.width), 
                       float32(gridDim) / float32(result.tex.height))

  setLen(result.tileTopLefts, tw*th)
  var idx = 0
  for y in 0..<th:
    for x in 0..<tw:
      result.tileTopLefts[idx] = (float32(x) * result.tileTexDim.x, float32(y) * result.tileTexDim.y)
      idx += 1

  # Transfer to callers resource set so we don't blow away the texture on exit.
  rset.take(lset)

proc aboutToDraw*(ts: TileSet) = 
  ## Call this before any batch of draw calls to set up GL state for drawing
  ## from this tilemap.
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, ts.tex.handle)

template withTileset*(ts: var TileSet; body: untyped) = 
  try:
    aboutToDraw(ts)
    body
  finally:
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, 0)

proc draw*(ts: var Tileset; batch: VertBatch[TxVtx,uint16];  tile: Natural; dest: AABB2f; z: float32 = 0) {.raises: [].} = 
  ## Draws tile #`tile` to `dest`.
  let tctl = ts.tileTopLefts[tile]
  let tcbr = tctl + ts.tileTexDim
  let dbr = dest.bottomRight

  triangulate(batch, [
    TxVtx(pos: vec3(dest.topLeft, z),       tc: tctl), 
    TxVtx(pos: (dbr.x, dest.topLeft.y, z),  tc: (tcbr.x, tctl.y)), 
    TxVtx(pos: vec3(dbr, z),                 tc: tcbr), 
    TxVtx(pos: (dest.topLeft.x, dbr.y, z),  tc: (tctl.x, tcbr.y))])



