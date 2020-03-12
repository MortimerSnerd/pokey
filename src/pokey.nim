import 
  blocksets, glstate, glsupport, geom, opengl, platform, sdl2, sdl2/image, 
  strformat, tilesets, verts, vfont, zstats

const
  WW=800
  WH=480

proc runLoop(gls: var GLState, window: WindowPtr, ts: var Tileset) = 
  var running = true

  #DEBUGGERY
  var bss: BlockSetSys
  let bs = bss.newBlockSet([TilePlacement(dx: 0, dy: 0, tile: 0), 
                    TilePlacement(dx: 1, dy: 0, tile: 1),
                    TilePlacement(dx: 2, dy: 0, tile: 2), 
                    TilePlacement(dx: 0, dy: 1, tile: 8), 
                    TilePlacement(dx: 1, dy: 1, tile: 9), 
                    TilePlacement(dx: 2, dy: 1, tile: 10), 
                    TilePlacement(dx: 0, dy: 2, tile: 16),
                    TilePlacement(dx: 1, dy: 2, tile: 17), 
                    TilePlacement(dx: 2, dy: 2, tile: 18)])

  echo repr(ts)

  while running:
    var ev{.noinit.}: sdl2.Event

    while pollEvent(ev):
      if ev.kind == QuitEvent:
        running = false
      elif ev.kind in [KeyUp, KeyDown]:
        case ev.key.keysym.sym
        of K_ESCAPE:
          running = false
        else:
          discard

    glClearColor(0, 0, 1, 1)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    gls.uni.mvp = orthoProjectionYDown[float32](0, WW, 0, WH, -2, 2)
    populate(gls.uniblk, GL_UNIFORM_BUFFER, gls.uni.addr, GL_DYNAMIC_DRAW)
    glViewport(0, 0, WW, WH)

    #TODO need a shader that takes a texture, umkay.
    use(gls.txShader)
    clear(gls.txbatch3)
    bindAndConfigureArray(gls.vtxs, TxVtxDesc)
    glEnable(GL_BLEND)
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
    withTileset(ts):
      ts.draw(gls.txbatch3, 3, (100.0f, 100.0f) @ (64.0f, 64.0f))
      draw(bss, bs, ts, gls.txbatch3, (200.0f, 200.0f))
      submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)
      glDisable(GL_BLEND)

    use(gls.solidColor)
    bindAndConfigureArray(gls.vtxs, VtxColorDesc)
    clear(gls.colorb)
    text(gls.colorb, "Eat more cheese", (100.0f, 100.0f), 1.5f)
    submitAndDraw(gls.colorb, gls.vtxs, gls.indices, GL_LINES)

    swapWindow(window)

proc go() = 
  var allRes: ResourceSet
  let imgflags = IMG_INIT_PNG.cint

  assert sdl2.init(INIT_VIDEO) == SdlSuccess, $sdl2.getError()
  assert image.init(imgflags) == imgflags, $sdl2.getError()

  let window = glsupport.init(allRes) do () -> WindowPtr:
    createWindow("Renderer Example", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, WW, WH, SDL_WINDOW_OPENGL)

  assert window != nil, $sdl2.getError()

  let surface = getSurface(window)
  assert surface != nil, $sdl2.getError()

  var gls = initGLState()
  var ts1 = initTileset(gls.rset, "platformertiles.png", 32)

  showCursor(false)
  vfont.init()

  try:
    runLoop(gls, window, ts1)
    echo GC_getStatistics()
    zstats.printReport()
  except:
    echo "UNCAUGHT EXCEPTION"
    var e = getCurrentException()
    while not e.isNil:
      echo(&"{e.msg}\n{e.getStackTrace()}")
      echo "---------"
      e = e.parent
  finally:
    destroyWindow(window)
    sdl2.quit()

go()
