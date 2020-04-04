## Essentially, brushes of multiple tiles
## that can be placed.
import
  chunks, chunktypes, geom, glstate, glsupport, handlers, 
  input, microui, opengl, os, platform, sdl2, streams, strformat, 
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

  BlockFile* = ref object
    ## Association of blocksets to the tileset they reference.
    ## BlockSet's are expected to only make sense for a particular
    ## tileset, as no ordering is enforced between different sets.
    blocks*: seq[BlockSet]
    ts*: Tileset

  InvalidBlock* = object of ValueError

const
  SerVer = 0

proc newBlockFile*(ts: Tileset) : BlockFile = 
  ## Creates a new empty BlockFile.
  BlockFile(ts: ts)

proc emptyBlockFile*() : BlockFile = 
  BlockFile(ts: emptyTileset())

proc serializeBlockset*(ss: Stream; bs: BlockSet) = 
  write(ss, Chunk(kind: ctBlockset, version: SerVer))
  write(ss, bs)

proc deserializeBlockset*(ss: Stream; bs: var BlockSet) = 
  var ch: Chunk
  read(ss, ch, ctBlockset)
  expectVersion(SerVer, ch.version, "BlockSet")
  read(ss, bs)

proc serialize*(ss: Stream; bb: BlockFile) = 
  write(ss, Chunk(kind: ctBlockFile, version: SerVer))
  writeSeq(ss, bb.blocks, serializeBlockset)
  serialize(ss, bb.ts)

proc deserialize(ss: Stream; rset: var ResourceSet; bb: var BlockFile) = 
  var ch: Chunk
  read(ss, ch, ctBlockFile)
  expectVersion(SerVer, ch.version, "BlockFile")
  readSeq(ss, bb.blocks, deserializeBlockset)
  deserialize(ss, rset, bb.ts)

proc blkFileFor(imgFile: string) : string = 
  ## Build absolute blk file path from img file path.
  return platform_data_path(imgFile & ".blk")

proc loadBlockFile*(imgFile: string; rset: var ResourceSet) : BlockFile = 
  ## Loads a new BlockFile for the given imgFile, and returns it.
  let blkFile = blkFileFor(imgFile)
  let ss = newFileStream(open(blkFile, fmRead))
  try:
    result = emptyBlockFile()
    deserialize(ss, rset, result)
  finally:
    close(ss)

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

proc numOverflowBlocks(bss: seq[BlockSet]; blk: Natural) : Natural = 
  ## For a given block, returns the number of overflow blocks associated
  ## with it.  Not valid to call this with ``blk`` pointing to an overflow block/
  assert bss[blk].num >= 0
  var bi = blk + 1
  while bi < len(bss) and bss[bi].num < 0:
    inc(result)

proc isOverflowBlock(bs: Blockset) : bool = 
  ## Returns true if this blockset isn't the start of a blockset, but
  ## overflow for a previous blockset.
  return bs.num < 0

proc deleteBlockset(bss: var seq[BlockSet]; blk: Natural) = 
  ## Deletes the blockset at the given index.  
  assert(not isOverflowBlock(bss[blk]))
  let no = numOverflowBlocks(bss, blk)

  for i in countdown(blk + no, blk):
    delete(bss, i)

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
    bb: BlockFile
      ## Association of the set of blocks and a TileSet

    ui: UIContext

    targetBlock: int
      ## Index of the bloc being edited.

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
  for tp in placements(c.bb.blocks, c.targetBlock):
    if tp.dx == dx and tp.dy == dy:
      tp.tile = uint16(tile)
      return

  # Doesn't exist, so add a tile.
  addInto(c.bb.blocks, c.targetBlock, TilePlacement(dx: dx, dy: dy, tile: uint16(tile)))

proc bseResumed(bc: Controller) = 
  let c = BlocksetEditor(bc)

  if c.pickedTile >= 0 and c.pickedTile < numTiles(c.bb.ts):
    c.curTile = c.pickedTile

proc bseHandleInput(bc: Controller, dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event
  let c = BlocksetEditor(bc)

  result = (Running, nil)

  while pollEvent(ev):
    if keyReleased(ev, K_ESCAPE, {}):
      result = (Finished, nil)
    elif keyReleased(ev, K_T, {Control}):
      c.pickedTile = -1
      result = (Running, newTilePicker(c.bb.ts, c.pickedTile.addr))
    else:
      case ev.kind
      of QuitEvent:
        result = (Finished, nil)

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

  return result

proc bseDraw(bc: Controller; gls: var GLState; dT: float32) = 
  let c = BlocksetEditor(bc)
  let gridDim = float32(c.bb.ts.gridDim)

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  aboutToDraw(c.bb.ts, gls)
  draw(c.bb.blocks, c.targetBlock, c.bb.ts, gls.txbatch3, (0.0f, 0.0f))

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
    let blk = addr c.bb.blocks[c.targetBlock]
    discard mu_textbox_ex(c.ui, addr blk.name[0], sizeof(blk.name).cint, 0) 
    mu_end_window(c.ui)

  mu_end(c.ui)
  render(c.ui, gls)

proc bseDeactivated*(cc: Controller) = 
  let c = BlocksetEditor(cc)

  #TODO if we cancelled, we need to remove any tiles we added to the BlockSetSys here.
  # Otherwise, block is added, caller can look at origLen to get the index of the new block
  # if needed.

proc newBlocksetEditor*(bb: BlockFile; ui: UIContext; blockIndex: int = -1) : BlocksetEditor = 
  ## Create a new blocket editor that's ready to be a controller.
  ## If blockIndex < 0, creates a new empty blockset, and edits that.
  assert blockIndex < len(bb.blocks)
  result = BlocksetEditor(bb: bb, ui: ui, 
                           targetBlock: if blockIndex < 0: len(bb.blocks) else: blockIndex, 
                           handleInput: bseHandleInput, draw: bseDraw, resumed: bseResumed, 
                           deactivated: bseDeactivated) 

  if blockIndex < 0:
    # Add an empty blockset to edit.
    add(result.bb.blocks, BlockSet(num: 0))

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

    bb: BlockFile
      ## Tileset and blocks being edited, possibly loaded from imgFile and blkFile.

    editIdx, deleteIdx: int
      ## Since microui reports input events as we're drawing it, we have these variables
      ## here to communicate button presses, selections back to the next invocation of handleInput.
      ## These are -1 if there was no input, or the index of a blockset if the edit or 
      ## delete buttons were pressed.

    doSave, doCancel: bool
      ## Cancel or save button pressed in GUI.

proc clearGuiInputs(c: TilesetEditor) = 
  c.editIdx = -1
  c.deleteIdx = -1
  c.doSave = false
  c.doCancel = false

proc tedHandleInput(bc: Controller, dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event
  let c = TilesetEditor(bc)

  result = (Running, nil)

  while pollEvent(ev):
    if ev.kind == QuitEvent or keyReleased(ev, K_ESCAPE, {}):
      result = (Finished, nil)
      break
    elif keyReleased(ev, sdl2.K_B, {Control}):
      result = (Running, newBlocksetEditor(c.bb, c.ui))
      break
    else:
      ui.feed(c.ui, ev)

  if result[0] != Finished:
    # Respond to any gui button presses from the last draw call.
    if c.editIdx >= 0:
      result = (Running, newBlocksetEditor(c.bb, c.ui, c.editIdx))
    elif c.deleteIdx >= 0:
      deleteBlockset(c.bb.blocks, c.deleteIdx)
    elif c.doSave:
      result = (Finished, nil)
      let ss = newFileStream(open(blkFileFor(c.imgFile), fmWrite))
      try:
        serialize(ss, c.bb)
      finally:
        close(ss)
    elif c.doCancel:
      result = (Finished, nil)

  clearGuiInputs(c)

  return result

proc tedDraw(bc: Controller; gls: var GLState; dT: float32) = 
  let c = TilesetEditor(bc)

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  clearGuiInputs(c)

  let wrect = centeredRect(gls, gls.wWi * 3 div 4, gls.wHi * 3 div 4)

  mu_begin(c.ui)
  if mu_begin_window(c.ui, "Tileset", wrect) != 0:
    layout_row(c.ui, [cint(-1)], -25)
    mu_begin_panel(c.ui, "Borks")
    layout_row(c.ui, [wrect.w div 2, wrect.w div 4, wrect.w div 4], 0)
    for i in 0..<len(c.bb.blocks):
      if not isOverflowBlock(c.bb.blocks[i]):
        mu_push_id(c.ui, unsafeAddr i, 8) 
        mu_label(c.ui, addr c.bb.blocks[i].name[0])
        if mu_button(c.ui, "edit") != 0:
          c.editIdx = i
        if mu_button(c.ui, "delete") != 0:
          c.deleteIdx = i
        mu_pop_id(c.ui)

    mu_end_panel(c.ui)

    layout_row(c.ui, [-(wrect.w + 40) div 4, wrect.w div 8, wrect.w div 8], 0)
    discard mu_layout_next(c.ui)
    if mu_button(c.ui, "Cancel") != 0:
      c.doCancel = true

    if mu_button(c.ui, "Save") != 0:
      c.doSave = true

    mu_end_window(c.ui)

  mu_end(c.ui)
  render(c.ui, gls)

proc newTilesetEditor*(ui: UIContext; imgFile: string; gridDim: Positive) : TilesetEditor = 
  ## Creates a new tileset editor for the given tileset image.
  ## ``imgFile`` must exist, or an IOError will be raised.
  ## If there is no corresponding block file a new one will be created
  ## on the next save operation.
  result = TilesetEditor(ui: ui, imgFile: imgFile, blkFile: blkFileFor(imgFile), editIdx: -1, 
                            deleteIdx: -1, handleInput: tedHandleInput,
                            draw: tedDraw)

  if existsFile(result.blkFile):
    result.bb = loadBlockFile(result.imgFile, result.rset)
  else:
    let ts = initTileset(result.rset, imgFile, gridDim)
    result.bb = newBlockFile(ts)

