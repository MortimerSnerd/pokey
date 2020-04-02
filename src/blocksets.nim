## Essentially, brushes of multiple tiles
## that can be placed.
import
  chunks, chunktypes, geom, glstate, glsupport, handlers, 
  input, microui, opengl, os, sdl2, streams, strformat, 
  tilesets, ui, verts

const
  BSSize = 8

type
  TilePlacement* = object
    ## Position of tile relative to top left of the BlockSet, in tiles.
    dx*, dy*: uint8 

    ## Index into a tileset for the tile.
    tile*: uint16

  BlockSet* = object
    ## Set of tiles for a blockset.  For blocksets with > BSSize
    ## tiles, the tiles can be defined over multiple BlockSet
    ## entries.  The overflow entries have a ``num < 0``.
    num: int32
    places: array[BSSize, TilePlacement]
    name*: array[8, char]

  BuildingBlocks* = ref object
    ## Association of blocksets to the tileset they reference.
    ## BlockSet's are expected to only make sense for a particular
    ## tileset, as no ordering is enforced between different sets.
    blocks*: seq[BlockSet]
    ts*: Tileset

  InvalidBlock* = object of ValueError

const
  SerVer = 0

proc newBuildingBlocks*(ts: Tileset) : BuildingBlocks = 
  ## Creates a new empty BuildingBlocks.
  BuildingBlocks(ts: ts)

proc serialize*(ss: Stream; bs: BlockSet) = 
  write(ss, Chunk(kind: ctBlockset, version: SerVer))
  write(ss, bs)

proc deserialize*(ss: Stream; bs: var BlockSet) = 
  var ch: Chunk
  read(ss, ch, ctBlockset)

  if ch.version != SerVer:
    raise newException(BadChunk, &"Unexpected BlockSet version {ch.version}")

  read(ss, bs)

proc addInto*(dest: var seq[BlockSet]; blkNum: int; tp: TilePlacement) = 
  ## Adds a tile placement into the BlockSet at blkNum.
  assert dest[blkNum].num >= 0
  var n = dest[blkNum].num
  var blk = blkNum

  while n >= 8:
    n -= 8
    inc blk

  if blk >= len(dest):
    add(dest, BlockSet(num: -1))

  dest[blk].places[n] = tp
  inc dest[blkNum].num     # Note, inc count on original, not the block we landed on.

proc newBlockSetInto*(dest: var seq[BlockSet]; pcs: openarray[TilePlacement]) = 
  ## Uses the items of ``pcs`` to create as many BlockSets as necessary to hold
  ## all the items.
  if len(pcs) == 0:
    raise newException(InvalidBlock, "No empty blocksets")

  var bs: BlockSet
  var first = true

  for pcidx in 0..<len(pcs):
    bs.places[bs.num] = pcs[pcidx]
    inc bs.num
    if bs.num == len(bs.places):
      if first:
        bs.num = int32(len(pcs))
        first = false
      else:
        bs.num = -1 # Mark as continuation.

      add(dest, bs)
      bs.num = 0

  if bs.num > 0:
    if first:
      bs.num = int32(len(pcs))
    else:
      bs.num = -1

    add(dest, bs)

iterator placements*(bss: var seq[BlockSet]; blkNum: int) : var TilePlacement = 
    if blkNum < len(bss):
      let np = bss[blkNum].num

      assert(np >= 0)
      var n = 0
      var blk = blkNum

      for i in 0..<np:
        yield bss[blk].places[n]
        inc n
        if n == BSSize:
          n = 0
          inc blk

proc draw*(bss: var seq[BlockSet]; blkNum: int; ts: var Tileset; batch: VertBatch[TxVtx,uint16]; topLeft: V2f; 
             z: float32 = 0; scale: float32 = 1.0f) = 
    ## Draws a blockset at the given position.
    let tilew = float32(ts.gridDim) * scale
    for tp in placements(bss, blkNum):
      let dx = float32(tp.dx) * tilew
      let dy = float32(tp.dy) * tilew
      let dest = (topLeft.x + dx, topLeft.y + dy) @ (tilew, tilew)

      ts.draw(batch, tp.tile, dest, z)


proc mouseToGridPos(ts: TileSet;  x, y: cint) : V2f = 
  floor(vec2(float32(x) / float32(ts.gridDim), float32(y) / float32(ts.gridDim)))

type
  BlocksetEditor* = ref object of Controller
    bb: BuildingBlocks
      ## Association of the set of blocks and a TileSet

    ui: UIContext

    origLen: int
      ## Original length of the BuildingBlocks.bss.  We use this
      ## to calc the block num of the tile we're editing, and to 
      ## undo the changes on cancel.

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

proc selectTile(c: TilePicker; mouseX, mouseY: cint) : int = 
  let gp = mouseToGridPos(c.ts, mouseX, mouseY)
  let idx = int(gp.y) * c.tilesAcross + int(gp.x) + c.page

  if idx < 0 or idx >= numTiles(c.ts):
    -1
  else:
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

  highlightMouseGrid(c.ts, gls)

proc newTilePicker*(ts: Tileset; retval: ptr int) : TilePicker = 
  ## Create a new tile picker that puts the index of the selected tile
  ## in `retval`, or a -1 if it is cancelled.
  assert retval != nil
  TilePicker(ts: ts, retval: retval, page: 0, 
              draw: tpkDraw, handleInput: tpkHandleInput)

proc changeTile(c: BlocksetEditor, mouseX, mouseY: cint, tile: int) = 
  ## Change the tile at the mouse position to `tile`.
  let gridPos = mouseToGridPos(c.bb.ts, mouseX, mouseY)
  
  if gridPos.x > 255 or gridPos.y > 255 or gridPos.x < 0 or gridPos.y < 0:
    return

  let dx = uint8(gridPos.x)
  let dy = uint8(gridPos.y)

  # If there's already a TilePlacement for this location, change it.
  for tp in placements(c.bb.blocks, c.origLen):
    if tp.dx == dx and tp.dy == dy:
      tp.tile = uint16(tile)
      return

  # Doesn't exist, so add a tile.
  addInto(c.bb.blocks, c.origLen, TilePlacement(dx: dx, dy: dy, tile: uint16(tile)))

proc bseResumed(bc: Controller) = 
  let c = BlocksetEditor(bc)

  if c.pickedTile >= 0 and c.pickedTile < numTiles(c.bb.ts):
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
        return (Running, newTilePicker(c.bb.ts, c.pickedTile.addr))
      else:
        discard

    of MouseButtonDown:
      
      if ev.button.button == BUTTON_LEFT and not windowContainsPoint(c.ui, ev.button.x, ev.button.y):
        changeTile(c, ev.button.x, ev.button.y, c.curTile)

    of MouseWheel:
      if ev.wheel.y > 0:
        c.curTile += 1
      elif ev.wheel.y < 0:
        c.curTile -= 1

      c.curTile = wrapToRange(c.bb.ts, c.curTile)

    else:
      discard

    ui.feed(c.ui, ev)

  return (Running, nil)

proc bseDraw(bc: Controller; gls: var GLState; dT: float32) = 
  let c = BlocksetEditor(bc)
  let gridDim = float32(c.bb.ts.gridDim)

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  aboutToDraw(c.bb.ts, gls)
  draw(c.bb.blocks, c.origLen, c.bb.ts, gls.txbatch3, (0.0f, 0.0f))

  # Draw scaled current tile in top right of window.
  let curTl = (gls.wW - gridDim*2, 0.0f)

  draw(c.bb.ts, gls.txbatch3, c.curTile, curTl @ (gridDim*2, gridDim*2), 0)
  submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)
  glDisable(GL_BLEND)

  highlightMouseGrid(c.bb.ts, gls)

  let wrect = blRect(gls, 250, 100)

  mu_begin(c.ui)

  if mu_begin_window(c.ui, "Properties", wrect) != 0:
    var cols = [cint(111), -1]
    mu_layout_row(c.ui, 2, addr cols[0], 0)
    mu_label(c.ui, "Name:")
    let blk = addr c.bb.blocks[c.origLen]
    discard mu_textbox_ex(c.ui, addr blk.name[0], sizeof(blk.name).cint, 0) 
    mu_end_window(c.ui)

  mu_end(c.ui)
  render(c.ui, gls)

proc bseDeactivated*(cc: Controller) = 
  let c = BlocksetEditor(cc)

  #TODO if we cancelled, we need to remove any tiles we added to the BlockSetSys here.
  # Otherwise, block is added, caller can look at origLen to get the index of the new block
  # if needed.

proc newBlocksetEditor*(bb: BuildingBlocks; ui: UIContext) : BlocksetEditor = 
  ## Create a new blocket editor that's ready to be a controller.
  result = BlocksetEditor(bb: bb, ui: ui, origLen: len(bb.blocks), 
                           handleInput: bseHandleInput, draw: bseDraw, resumed: bseResumed, 
                           deactivated: bseDeactivated) 
  # Add an empty blockset to start with.
  add(bb.blocks, BlockSet(num: 0))

type
  TilesetEditor* = ref object of Controller
    ## Allows creation and editing of BlockSets associated
    ## with a Tileset, and any per-tile properties.
    rset: ResourceSet
      ## ResourceSet scoped to the lifetime of this editor.

    ui: UIContext
     
    imgFile: string
      ## relative path to the image for the tileset.

    blkFile: string
      ## relative path to the blk file that contains the per tile
      ## and blockset information.

    bb: BuildingBlocks
      ## Tileset and blocks being edited, possibly loaded from imgFile and blkFile.

    editIdx, deleteIdx: int
      ## Since microui reports input events as we're drawing it, we have these variables
      ## here to communicate button presses, selections back to the next invocation of handleInput.
      ## These are -1 if there was no input, or the index of a blockset if the edit or 
      ## delete buttons were pressed.

proc blkFileFor(imgFile: string) : string = 
  ## Build blk file path from img file path.
  return imgFile & ".blk"

proc tedHandleInput(bc: Controller, dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event
  let c = TilesetEditor(bc)

  result = (Running, nil)

  while pollEvent(ev):
    if ev.kind == QuitEvent or keyReleased(ev, K_ESCAPE, {}):
      return (Finished, nil)
    elif keyReleased(ev, sdl2.K_B, {Control}):
      return (Running, newBlocksetEditor(c.bb, c.ui))
    else:
      ui.feed(c.ui, ev)

  # Respond to any gui button presses from the last draw call.
  if c.editIdx >= 0:
    echo &"Ja, edit {c.editIdx}"
  elif c.deleteIdx >= 0:
    del(c.bb.blocks, c.deleteIdx)

  c.editIdx = -1
  c.deleteIdx = -1

  return result

proc tedDraw(bc: Controller; gls: var GLState; dT: float32) = 
  let c = TilesetEditor(bc)

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  c.editIdx = -1
  c.deleteIdx = -1

  let wrect = centeredRect(gls, gls.wWi * 3 div 4, gls.wHi * 3 div 4)

  mu_begin(c.ui)
  if mu_begin_window(c.ui, "Tileset", wrect) != 0:
    layout_row(c.ui, [cint(-1)], -25)
    mu_begin_panel(c.ui, "Borks")
    layout_row(c.ui, [wrect.w div 2, wrect.w div 4, wrect.w div 4], 0)
    for i in 0..<len(c.bb.blocks):
      mu_push_id(c.ui, unsafeAddr i, 8) 
      mu_label(c.ui, addr c.bb.blocks[i].name[0])
      if mu_button(c.ui, "edit") != 0:
        c.editIdx = i
      if mu_button(c.ui, "delete") != 0:
        c.deleteIdx = i
      mu_pop_id(c.ui)

    mu_end_panel(c.ui)
    mu_end_window(c.ui)


  mu_end(c.ui)
  render(c.ui, gls)

proc newTilesetEditor*(ui: UIContext; imgFile: string; gridDim: Positive) : TilesetEditor = 
  ## Creates a new tileset editor for the given tileset image.
  ## ``imgFile`` must exist, or an IOError will be raised.
  ## If there is no corresponding block file a new one will be created
  ## on the next save operation.
  let r = TilesetEditor(ui: ui, imgFile: imgFile, editIdx: -1, 
                            deleteIdx: -1, handleInput: tedHandleInput,
                            draw: tedDraw)
  let ts = initTileset(r.rset, imgFile, gridDim)
  r.bb = newBuildingBlocks(ts)
  r.blkFile = blkFileFor(imgFile)

  if existsFile(r.blkFile):
    echo "should probably implement block file loading"

  return r
