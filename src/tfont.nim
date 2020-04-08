## TTF font support, where letters are cached to a
## texture.
import
    bitops, geom, glstate, glsupport, opengl, sdl2, sdl2/ttf, strformat, unicode, 
    verts

const
    # Dimensions of cache textures.
    CacheW = 512
    CacheH = 512

type
    TFont* = ref object
        rset: ResourceSet
        path: string
        ptsize: int
        font: FontPtr
        txts: seq[Texture]
        backingSurfs: seq[SurfacePtr]
        letters: seq[Rune]
        metrics: seq[RuneMetric]
        curPage: int
        nextTL: V2i
          ## Top left coordinate of next available space for new characters in the
          ## backing surface.

    RuneMetric = object
        xadvance: int
        tc: AABB2f
          ## Texture coords.
        page: byte

var initialized = false

proc addPageToCache(tf: TFont) =
    let s = createCompatSurface(CacheW, CacheH)
    if s == nil:
        raise newException(ValueError, &"Failed creating surface: {$sdl2.getError()}")

    try:
        let t = loadTexture(cast[ptr byte](s.pixels), CacheW, CacheH, DispGLFormatIntern, DispGLFormatIntern)
        applyParameters(t, TextureParams(minFilter: GL_LINEAR, magFilter: GL_LINEAR, wrapS: GL_REPEAT, wrapT: GL_REPEAT))
        add(tf.backingSurfs, s)
        add(tf.txts, t)
        add(tf.rset, rkTexture, t.handle)
    except:
        destroy(s)
        raise

proc findLetter(tf: TFont; r: Rune) : int = 
  result = -1
  for i in 0..<len(tf.letters):
    if tf.letters[i] == r:
      result = i
      break

iterator letterPositions(tf: TFont; s: string; pos: var V2i) : (Rune, V2i, AABB2f, int, int) = 
  ## Yields Rune, pos relative to start, texture coordinate 
  ## bounding box, the page, and the xadvance
  ## for each rune in the string.  Assumes all of the needed
  ## runes are cached.  If that's not true, it will skip letters it can't find.
  let startpos = pos
  for r in runes(s):
    if r == Rune(32):
      let li = findLetter(tf, Rune(ord('w')))

      if li >= 0:
        yield (r, pos, (0.0f, 0.0f) @ (0.0f, 0.0f), 0, tf.metrics[li].xadvance)
        pos.x += tf.metrics[li].xadvance
    elif int(r) == ord('\n'):
      pos.y += fontHeight(tf.font).int + 2
      pos.x = startpos.x
    else:
      let li = findLetter(tf, r)

      if li >= 0:
        yield (r, pos, tf.metrics[li].tc, tf.metrics[li].page.int, tf.metrics[li].xadvance)
        pos.x += tf.metrics[li].xadvance

proc textWidth*(tf: TFont; msg: string) : float32 = 
  var pos = vec2(0, 0)

  for r, cpos, tc, page, xadvance in letterPositions(tf, msg, pos):
    result = max(result, float32(pos.x))

  return float32(pos.x)

proc fontHeight*(tf: TFont) : int = 
  fontHeight(tf.font)


proc addUnknownRune(tf: TFont; r: Rune) = 
  ## Adds `r` as an unknown rune, that displays as a ?
  ## Does nothing if there is no '?' in the font.
  let li = findLetter(tf, Rune(ord('?')))
  if li >= 0:
    add(tf.letters, r)
    add(tf.metrics, tf.metrics[li])

proc placeRuneInCache(tf: TFont; r: Rune) : (bool, AABB2f) = 
  ## Adds the rune to the local surface cache.
  ## Runes have a 1 pixel border around them to avoid
  ## blending artifacts.  Returns the texture coord bounding
  ## box of the resultant letter.  Returns false if the letter
  ## could not be found or rendered.
  var rs = [uint16(r), 0]
  let rsurf = renderUnicodeBlended(tf.font, addr rs[0], White)
 
  defer: destroy(rsurf) 
  if rsurf != nil:
    let w = rsurf.w.int + 2
    let h = rsurf.h.int + 2
    let rhs = tf.nextTL.x + w
    
    if rhs > CacheW:
      tf.nextTl = (0, tf.nextTl.y + fontHeight(tf.font) + 2)
      let bot = tf.nextTl.y + fontHeight(tf.font) + 2
      if bot > CacheH:
        addPageToCache(tf)
        tf.nextTl = (0, 0)
        inc(tf.curPage)

    let tl = tf.nextTl + (1, 1) 
    let srcr: sdl2.Rect = (x: 0.cint, y: 0.cint, w: rsurf.w, h: rsurf.h)
    let destr: sdl2.Rect = (x: tl.x.cint, y: tl.y.cint, w: rsurf.w, h: rsurf.h)

    discard blitSurface(rsurf, unsafeAddr srcr, 
                        tf.backingSurfs[tf.curPage], unsafeAddr destr)
    tf.nextTl.x += w
    result = (true, (tl.x.float32 / CacheW, tl.y.float32 / CacheH) @ (rsurf.w.float32 / CacheW, rsurf.h.float32 / CacheH))

proc maybeCacheUnknownLetters(tf: TFont; txt: string) : int = 
  ## Renders any letters we don't have a glyph for into 
  ## the local cache. Returns bitmask of pages that were
  ## changed.
  assert len(tf.letters) == len(tf.metrics)
  assert tf.curPage <= 8
  for r in runes(txt):
    let li = findLetter(tf, r)
    if li < 0:
      # TTF interface only takes Unicode up to 65535
      if r.int > high(uint16).int:
        addUnknownRune(tf, r)
      else:
        var minx, maxx, miny, maxy, advance: cint

        if glyphMetrics(tf.font, r.uint16, addr minx, addr maxx, addr miny, addr maxy, addr advance) == 0:
          let (ok, tc) = placeRuneInCache(tf, r)

          if ok:
            add(tf.letters, r)
            add(tf.metrics, RuneMetric(xadvance: advance, tc: tc, page: tf.curPage.byte))
            result = result or 1 shl tf.curPage
          else:
            addUnknownRune(tf, r)

proc drawText*(tf: TFont; gls: var GLState; pos: V2f; msg: string; z: float32 = 0) = 
  ## Draws the text onto the screen.  Sets up the GL state to do the drawing.
  var lastPage = -1
  var relPos = vec2(0, 0)

  var pageMask = maybeCacheUnknownLetters(tf, msg) #TODO check bitmask for updated pages.
  var page = 0
  while pageMask > 0:
    if bitand(pageMask, 1) != 0:
      upload(tf.txts[page], tf.backingSurfs[page])
    pageMask = pageMask shr 1
    inc(page)

  use(gls.txShader)
  glActiveTexture(GL_TEXTURE0)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  use(gls.txShader)
  clear(gls.txbatch3)
  bindAndConfigureArray(gls.vtxs, TxVtxDesc)

  let h = float32(fontHeight(tf.font)) #TODO bad, need to do per letter.
  for r, cpos, tc, page, xadvance in letterPositions(tf, msg, relPos):
    let tl = vec2(cpos.x.float32, cpos.y.float32) + pos
    let w = float32(xadvance)
    let tcbr = tc.bottomRight

    if page != lastPage:
      lastPage = page
      submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)
      clear(gls.txbatch3)
      glBindTexture(GL_TEXTURE_2D, tf.txts[page].handle)

    triangulate(gls.txbatch3, [
      TxVtx(pos: vec3(tl.x, tl.y, z), tc: tc.topLeft), 
      TxVtx(pos: vec3(tl.x + w, tl.y, z), tc: (tcbr.x, tc.topLeft.y)), 
      TxVtx(pos: vec3(tl.x + w, tl.y + h, z), tc: tcbr), 
      TxVtx(pos: vec3(tl.x, tl.y + h, z), tc: (tc.topLeft.x, tcbr.y))])

  submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)


proc newTFont*(path: string, ptsize: Positive) : TFont =
    ## Creates a new tfont, with common characters already
    ## cached.
    if not initialized:
        if ttfInit() != SDL_SUCCESS:
            raise newException(IOError, &"ttfInit: {$sdl2.getError()}")
        initialized = true

    result = TFont(
      path: path,
      ptsize: ptsize,
      font: openFont(path, cint(ptsize)))

    if result.font == nil:
        raise newException(IOError, &"Error loading {path}: {$sdl2.getError()}")

    addPageToCache(result)
    discard maybeCacheUnknownLetters(result, "ABCDEFGHIJKLMNOQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!@#$%^&*(),./ <>?;':7\"[]\\{}|")
    for i, tx in pairs(result.txts):
      upload(tx, result.backingSurfs[i])

proc disposeOf*(tf: TFont) =
    `=destroy`(tf.rset)
