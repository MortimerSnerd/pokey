import
  chunks, chunktypes, geom, glstate, glsupport, handlers, 
  input, microui, opengl, sdl2, streams, strformat, ui, verts

const TsVer = 2

type
  TileProps* = enum
    BlocksCharacters,   ## Blocks movement through tile from all directions.

  Tileset* = object
    ## A tileset for an image divided up into uniform gridDim x gridDim 
    ## tiles.
    file: string ## Relative path to image file that backs this.
    tex: Texture
    gridDim*: Positive ## Tiles are forced to be square, gridDim*gridDim
    tileTopLefts: seq[V2f] ## Topleft texture coordinates for each tile.
    tileTexDim: V2f ## Width and height of a tile in texture coordinates.
    properties: seq[set[TileProps]]

  BadTileDims = object of ValueError

proc emptyTileset*() : Tileset = 
  Tileset(gridDim: 1)

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

  setLen(result.properties, tw*th)
  setLen(result.tileTopLefts, tw*th)
  var idx = 0
  for y in 0..<th:
    for x in 0..<tw:
      result.tileTopLefts[idx] = (float32(x) * result.tileTexDim.x, float32(y) * result.tileTexDim.y)
      idx += 1

  # Transfer to callers resource set so we don't blow away the texture on exit.
  rset.take(lset)

proc serialize*(ss: Stream; ts: var Tileset) = 
  ## Just save enough info so we can call initTileset to reload everything.
  write(ss, Chunk(kind: ctTileset, version: TsVer))
  writeString(ss, ts.file)
  write(ss, ts.gridDim)
  writeSeq(ss, ts.properties)

proc deserialize*(ss: Stream; rset: var ResourceSet; ts: var Tileset) = 
  var ch: Chunk
  read(ss, ch, ctTileset)

  if ch.version notin [1,2]:
    raise newException(BadChunk, &"Unexpected Tileset version {ch.version}")

  var imgFile: string
  readString(ss, imgFile)
  var gridDim: int
  read(ss, gridDim)
  if gridDim <= 0:
    raise newException(BadChunk, &"Negative grid dimensions for tileset: {gridDim}")

  ts = initTileset(rset, imgFile, gridDim)
  readSeq(ss, ts.properties)

proc numTiles*(ts: Tileset) : int = len(ts.tileTopLefts)

proc aboutToDraw*(ts: TileSet; gls: var GLState) = 
  ## Call this before any batch of draw calls to set up GL state for drawing
  ## from this tilemap.
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, ts.tex.handle)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  use(gls.txShader)
  clear(gls.txbatch3)
  bindAndConfigureArray(gls.vtxs, TxVtxDesc)

template withTileset*(ts: var TileSet; gls: var GLState; body: untyped) = 
  try:
    aboutToDraw(ts, gls)
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

proc wrapToRange*(ts: Tileset; tileIdx: int) : int = 
  ## If the tileIdx is out of range for this tileset, 
  ## wraps it around back to a valid number.
  if tileIdx < 0:
    return len(ts.tileTopLefts)-1
  elif tileIdx >= len(ts.tileTopLefts):
    return 0
  else:
    return tileIdx

type
  TilesetPropertyEditor* = ref object of Controller
    ## GUI that allows you to change per-tile properties
    ## for the tiles in a Tileset.
    ui: UIContext

    tset: Tileset
      ## Tileset that's being edited.

    srcTset: ptr Tileset
      ## This is the tileset we copy to if the user saves.

    curTile: Natural
      ## Which tile is currently having its properties edited.

    doCancel, doSave: bool
      ## Are the cancel or save buttons pressed?

proc tpeHandleInput(cc: Controller; dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event
  let c = TilesetPropertyEditor(cc)

  result = (Running, nil)
  while pollEvent(ev):
    if ev.kind == QuitEvent or keyReleased(ev, K_ESCAPE, {}):
      result = (Finished, nil)
      break
    else:
      ui.feed(c.ui, ev)

  if c.doCancel:
    result = (Finished, nil)
  elif c.doSave:
    c.srcTset[] = c.tset
    result = (Finished, nil)

  return result

proc tpeDraw(cc: Controller; gls: var GLState; dT: float32) = 
  let c = TilesetPropertyEditor(cc)

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  let wrect = centeredRect(gls, gls.wWi * 3 div 4, gls.wHi * 3 div 4)
  var tileLocs: seq[V2f]
  var panel: ptr mu_Container
  const nProps = ord(high(TileProps)) + 1
  let cwi = (gls.wWi - cint(c.tset.gridDim) - 4) div nProps
  var tileCols: array[1 + nProps, cint] = [cint(c.tset.gridDim) + 4, cwi]
  
  mu_begin(c.ui)
  if mu_begin_window(c.ui, "Tileset Properties", wrect) != 0:
    layout_row(c.ui, [cint(-20)], -60)
    mu_begin_panel(c.ui, "Tiles")
    panel = mu_get_current_container(c.ui)
    for i in 0..<numTiles(c.tset):
      layout_row(c.ui, tileCols, cint(c.tset.gridDim) + 5)
      let r = mu_layout_next(c.ui)
      add(tileLocs, (r.x.float32, r.y.float32))
      for tp in TileProps:
        var st = if tp in c.tset.properties[i]: cint(-1) else: cint(0)
        let id = (tp, i)
        mu_push_id(c.ui, unsafeAddr id, sizeof(id).cint)
        discard mu_checkbox(c.ui, $tp, addr st)
        if st != 0:
          incl(c.tset.properties[i], tp)
        else:
          excl(c.tset.properties[i], tp)
        mu_pop_id(c.ui)

    mu_end_panel(c.ui)

    layout_row(c.ui, [-(wrect.w + 40) div 4, wrect.w div 8, wrect.w div 8], 0)
    discard mu_layout_next(c.ui)
    c.doCancel = mu_button(c.ui, "Cancel") != 0
    c.doSave = mu_button(c.ui, "Save") != 0

    mu_end_window(c.ui)

  mu_end(c.ui)
  render(c.ui, gls)

  if panel != nil:
    # Now use our saved position to render the tiles in the correct location for the gui.
    let gdims = vec2(c.tset.gridDim.float32, c.tset.gridDim.float32)

    glEnable(GL_SCISSOR_TEST)
    glScissor(panel.rect.x, gls.wHi - (panel.rect.y + panel.rect.h), panel.rect.w, panel.rect.h);
    withTileset(c.tset, gls):
      for i, loc in pairs(tileLocs):
        draw(c.tset, gls.txbatch3, i, loc @ gdims)

      submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)
    glScissor(0, 0, gls.wWi, gls.wHi)
    glDisable(GL_SCISSOR_TEST)

proc newTilesetPropertyEditor*(ui: UIContext; ts: ptr Tileset) : TilesetPropertyEditor = 
  ## Creates a new property edtitor for the tileset.  ``ts`` must have a lifetime
  ## greater than this editor.  (which is usually implied given the stack discipline of
  ## controllers in the handlers module.
  result = TilesetPropertyEditor(ui: ui, tset: ts[], srcTset: ts, curTile: 0, 
                                     handleInput: tpeHandleInput, draw: tpeDraw)
