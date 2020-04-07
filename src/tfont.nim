## TTF font support, where letters are cached to a
## texture.
import
    geom, glsupport, opengl, sdl2, sdl2/ttf, strformat, unicode

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
        xadvance: float32
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
            add(tf.metrics, RuneMetric(xadvance: advance.float32, tc: tc, page: tf.curPage.byte))
            result = result or 1 shl tf.curPage
          else:
            addUnknownRune(tf, r)


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
