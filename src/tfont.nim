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
        nextTL: V2f
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
        add(tf.backingSurfs, s)
        add(tf.txts, t)
        add(tf.rset, rkTexture, t.handle)
    except:
        destroy(s)
        raise

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

proc disposeOf*(tf: TFont) =
    `=destroy`(tf.rset)
