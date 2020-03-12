## Essentially, brushes of multiple tiles
## that can be placed.
import
  geom, glsupport, tilesets, verts

type
  BlockSetSys* = object
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

proc newBlockSet*(bss: var BlockSetSys; pcs: openarray[TilePlacement]) : BlockSet {.raises: [InvalidBlock].} = 
  ## Create a new block set with the given tile placements.
  if len(pcs) == 0:
    raise newException(InvalidBlock, "No empty blocksets")

  let start = len(bss.tiles)
  add(bss.tiles, pcs)
  let last = len(bss.tiles)-1
  return BlockSet(tileStart: start, tileLast: last)

proc draw*(sys: var BlockSetSys; bs: BlockSet; ts: var Tileset; batch: VertBatch[TxVtx,uint16]; topLeft: V2f; 
             z: float32 = 0; scale: float32 = 1.0f) = 
    ## Draws a blockset at the given position.
    let tilew = float32(ts.gridDim) * scale
    for i in bs.tileStart..bs.tileLast:
      let tp = sys.tiles[i].addr
      let dx = float32(tp.dx) * tilew
      let dy = float32(tp.dy) * tilew
      let dest = (topLeft.x + dx, topLeft.y + dy) @ (tilew, tilew)

      ts.draw(batch, tp.tile, dest, z)

