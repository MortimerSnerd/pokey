## Essentially, brushes of multiple tiles
## that can be placed.
import
  geom, glstate, glsupport, handlers, opengl, sdl2, 
  strformat, tilesets, verts, vfont

type
  BlockSetSys* = ref object
    ## sequence of relative tile positions.  This 
    ## is storage for all of the tile positions for all
    ## BlockSets, which refer back to this array.
    tiles: seq[TilePlacement]

  TilePlacement* = object
    ## Position of tile relative to top left of the BlockSet, in tiles.
    dx*, dy*: uint8 

    ## Index into a tileset for the tile.
    tile*: uint16

  BlockSet* = object
    tileStart, tileLast: int ## Inclusive range of tiles in BlockSetSys.

  InvalidBlock* = object of Exception

proc newBlockSetSys*() : BlockSetSys = 
  BlockSetSys()

proc newBlockSet*(bss: BlockSetSys; pcs: openarray[TilePlacement]) : BlockSet {.raises: [InvalidBlock].} = 
  ## Create a new block set with the given tile placements.
  if len(pcs) == 0:
    raise newException(InvalidBlock, "No empty blocksets")

  let start = len(bss.tiles)
  add(bss.tiles, pcs)
  let last = len(bss.tiles)-1
  return BlockSet(tileStart: start, tileLast: last)

proc draw*(sys: BlockSetSys; bs: BlockSet; ts: var Tileset; batch: VertBatch[TxVtx,uint16]; topLeft: V2f; 
             z: float32 = 0; scale: float32 = 1.0f) = 
    ## Draws a blockset at the given position.
    let tilew = float32(ts.gridDim) * scale
    for i in bs.tileStart..bs.tileLast:
      let tp = sys.tiles[i].addr
      let dx = float32(tp.dx) * tilew
      let dy = float32(tp.dy) * tilew
      let dest = (topLeft.x + dx, topLeft.y + dy) @ (tilew, tilew)

      ts.draw(batch, tp.tile, dest, z)


proc mouseToGridPos(ts: TileSet;  x, y: cint) : V2f = 
  floor(vec2(float32(x) / float32(ts.gridDim), float32(y) / float32(ts.gridDim)))

type
  BlocksetEditor* = ref object of Controller
    bss: BlockSetSys
      ## Creater of blocks. This is the one we add the blockset to
      ## when done.

    origBssLen: int 
      ## The length of the bss.tiles when we started. 
      ## We add TilePlacement's to the end and use
      ## this to keep track of where tileStart shoudl be for
      ## editBS.

    editBS: BlockSet
      ## The temp blockset we are editing.

    ts: TileSet
      ## Tileset the blockset is built from.

    curTile: int
      ## Tile that will be drawn when the mouse button is clicked.

    pickedTile: int
      ## Used to communicate the picked tile between the
      ## editor and the TilePicker.

  TilePicker = ref object of Controller
    ## Displays all of the tiles, ending when the 
    ## user selects a tile.
    ts: Tileset
    retval: ptr int

    numPerPage: int
      ## Calculated number of tiles that fit on a page.

    tilesAcross: int
      ## Number of tiles that can fit horizontally 
      ## on the screen.

    page: int
      ## Big tilesets won't fit on one screen, so 
      ## we'll need to page them.  This is the 
      ## index of the first tile we should display.


#TODO how to push a new controller.  Return it from handleInput somehow?
proc selectTile(c: TilePicker; mouseX, mouseY: cint) : int = 
  let gp = mouseToGridPos(c.ts, mouseX, mouseY)
  let idx = int(gp.y) * c.tilesAcross + int(gp.x) + c.page

  if idx < 0 or idx >= numTiles(c.ts):
    -1
  else:
    echo &"Jimmy: {idx}"
    idx

proc tpkHandleInput(bc: Controller, dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event
  let c = TilePicker(bc)

  while pollEvent(ev):
    case ev.kind
    of QuitEvent:
      c.retval[] = -1
      return (Finished, nil)

    of KeyUp:
      case ev.key.keysym.sym
      of K_ESCAPE:
        return (Finished, nil)
      else:
        discard

    of MouseButtonDown:
      if ev.button.button == BUTTON_LEFT:
        c.retval[] = selectTile(c, ev.button.x, ev.button.y)
        if c.retval[] >= 0:
          echo "BOOT"
          return (Finished, nil)

    of MouseWheel:
      #TODO page up and down?
      discard

    else:
      discard

  return (Running, nil)

proc tpkDraw(bc: Controller; gls: var GLState; dT: float32) = 
  let c = TilePicker(bc)
  let gridDim = float32(c.ts.gridDim)

  if c.numPerPage == 0:
    let numX = int(gls.wWi) div c.ts.gridDim
    let numY = int(gls.wHi) div c.ts.gridDim

    c.numPerPage = numX*numY
    assert c.numPerPage >= 0
    c.tilesAcross = numX

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)
  aboutToDraw(c.ts, gls)

  var tno = c.page
  var sx = 0.0f
  var sy = 0.0f

  block outer:
    while tno < c.ts.numTiles():
      c.ts.draw(gls.txbatch3, tno, (sx, sy) @ (gridDim, gridDim), 0)
      sx += gridDim
      if (sx + gridDim) > gls.wW:
        sx = 0.0f
        sy += gridDim
        if (sy + gridDim) > gls.wH:
          break outer
      tno += 1

  submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)

proc newTilePicker*(ts: Tileset; retval: ptr int) : TilePicker = 
  ## Create a new tile picker that puts the index of the selected tile
  ## in `retval`, or a -1 if it is cancelled.
  assert retval != nil
  TilePicker(ts: ts, retval: retval, page: 0, 
              draw: tpkDraw, handleInput: tpkHandleInput)

proc changeTile(c: BlocksetEditor, mouseX, mouseY: cint, tile: int) = 
  ## Change the tile at the mouse position to `tile`.
  let gridPos = mouseToGridPos(c.ts, mouseX, mouseY)
  
  if gridPos.x > 255 or gridPos.y > 255 or gridPos.x < 0 or gridPos.y < 0:
    return

  let dx = uint8(gridPos.x)
  let dy = uint8(gridPos.y)

  # If there's already a TilePlacement for this location, change it.
  if c.origBssLen < len(c.bss.tiles):
    for i in c.editBS.tileStart..c.editBS.tileLast:
      let tp = c.bss.tiles[i].addr
      if tp.dx == dx and tp.dy == dy:
        tp.tile = uint16(tile)
        return

  # Doesn't exist, so add a tile.
  add(c.bss.tiles, TilePlacement(dx: dx, dy: dy, tile: uint16(tile)))
  inc(c.editBS.tileLast)

proc bseResumed(bc: Controller) = 
  let c = BlocksetEditor(bc)
  echo &"ASS {c.pickedTile} {numTiles(c.ts)}"

  if c.pickedTile >= 0 and c.pickedTile < numTiles(c.ts):
    echo "yarrrrr"
    c.curTile = c.pickedTile

proc bseHandleInput(bc: Controller, dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event
  let c = BlocksetEditor(bc)

  while pollEvent(ev):
    case ev.kind
    of QuitEvent:
      return (Finished, nil)

    of KeyUp:
      case ev.key.keysym.sym
      of K_ESCAPE:
        return (Finished, nil)
      of K_T:
        c.pickedTile = -1
        return (Running, newTilePicker(c.ts, c.pickedTile.addr))
      else:
        discard

    of MouseButtonDown:
      if ev.button.button == BUTTON_LEFT:
        changeTile(c, ev.button.x, ev.button.y, c.curTile)

    of MouseWheel:
      if ev.wheel.y > 0:
        c.curTile += 1
      elif ev.wheel.y < 0:
        c.curTile -= 1

      c.curTile = wrapToRange(c.ts, c.curTile)

    else:
      discard

  return (Running, nil)

proc highlightMouseGrid(ts: Tileset; gls: var GLState) = 
  ## Draw lines around the grid position where the mouse is.
  let gridDim = float32(ts.gridDim)
  var mx, my: cint
  getMouseState(mx, my)
  let gp = mouseToGridPos(ts, mx, my)

  drawingLines(gls, {Submit}):
    addLines(gls.colorb, gp*gridDim @ (gridDim, gridDim),
              proc (v: V2f, num: int) : VtxColor =
                VtxColor(pos: v, color: WhiteG))

proc bseDraw(bc: Controller; gls: var GLState; dT: float32) = 
  let c = BlocksetEditor(bc)
  let gridDim = float32(c.ts.gridDim)

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  aboutToDraw(c.ts, gls)
  if len(c.bss.tiles) > c.origBssLen:
    c.editBS.tileLast = len(c.bss.tiles) - 1
    c.bss.draw(c.editBS, c.ts, gls.txbatch3, (0.0f, 0.0f))

  # Draw scaled current tile in top right of window.
  let curTl = (gls.wW - gridDim*2, 0.0f)

  c.ts.draw(gls.txbatch3, c.curTile, curTl @ (gridDim*2, gridDim*2), 0)
  submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)
  glDisable(GL_BLEND)

  highlightMouseGrid(c.ts, gls)


proc newBlocksetEditor*(bss: BlockSetSys, ts: TileSet) : BlocksetEditor = 
  ## Create a new blocket editor that's ready to be a controller.
  return BlocksetEditor(bss: bss, ts: ts, origBssLen: len(bss.tiles), 
                           editBS: BlockSet(tileStart: len(bss.tiles), tileLast: len(bss.tiles)), 
                           handleInput: bseHandleInput, draw: bseDraw, resumed: bseResumed) 

