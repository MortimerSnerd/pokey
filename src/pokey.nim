import 
  blocksets, glstate, glsupport, geom, handlers, opengl, 
  platform, sdl2, sdl2/image, strformat, tilesets, verts, vfont, zstats

const
  WW=800
  WH=480

type
  TestController = ref object of Controller
    ts: Tileset
    bss: BlockSetSys
    bs: BlockSet

proc tcDraw(bc: Controller, gls: var GLState, dT: float32) = 
  let c = TestController(bc) # This will raise InvalidObjectConversion if something goes wrong.

  fullScreenOrtho(gls)
  setUniforms(gls)
  glViewport(0, 0, gls.wWi, gls.wHi)

  #TODO need a shader that takes a texture, umkay.
  use(gls.txShader)
  clear(gls.txbatch3)
  bindAndConfigureArray(gls.vtxs, TxVtxDesc)
  glEnable(GL_BLEND)
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  withTileset(c.ts, gls):
    draw(c.ts, gls.txbatch3, 3, (100.0f, 100.0f) @ (64.0f, 64.0f))
    draw(c.bss, c.bs, c.ts, gls.txbatch3, (200.0f, 200.0f), 0, 2)
    submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)
    glDisable(GL_BLEND)

  use(gls.solidColor)
  bindAndConfigureArray(gls.vtxs, VtxColorDesc)
  clear(gls.colorb)
  text(gls.colorb, "Eat more cheese", (100.0f, 100.0f), 1.5f)
  submitAndDraw(gls.colorb, gls.vtxs, gls.indices, GL_LINES)

proc tcHandleInput(c: Controller, dT: float32) : (InHandlerStatus, Controller) = 
  var ev{.noinit.}: sdl2.Event

  while pollEvent(ev):
    if ev.kind == QuitEvent:
      return (Finished, nil)
    elif ev.kind in [KeyUp]:
      case ev.key.keysym.sym
      of K_ESCAPE:
        return (Finished, nil)
      else:
        discard

  return (Running, nil)

proc tcActivated(bc: Controller) = 
  let c = TestController(bc)

  c.bs = c.bss.newBlockSet([TilePlacement(dx: 0, dy: 0, tile: 0), 
                    TilePlacement(dx: 1, dy: 0, tile: 1),
                    TilePlacement(dx: 2, dy: 0, tile: 2), 
                    TilePlacement(dx: 0, dy: 1, tile: 8), 
                    TilePlacement(dx: 1, dy: 1, tile: 9), 
                    TilePlacement(dx: 2, dy: 1, tile: 10), 
                    TilePlacement(dx: 0, dy: 2, tile: 16),
                    TilePlacement(dx: 1, dy: 2, tile: 17), 
                    TilePlacement(dx: 2, dy: 2, tile: 18)])

proc runLoop(gls: var GLState, ts: var Tileset) = 
  let cm = newControllerManager()
  var running = true
  var tpret: int = 0

  let tc = TestController(bss: newBlockSetSys(), ts: ts, handleInput: tcHandleInput, draw: tcDraw, 
                             activated: tcActivated)
  add(cm, tc)
  add(cm, newBlockSetEditor(tc.bss, tc.ts))

  while running:
    frameStart(gls)
    glClearColor(0, 0, 1, 1)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    running = processFrame(cm, gls, 0.1)
    swapWindow(gls.window)

proc go() = 
  var allRes: ResourceSet
  let imgflags = IMG_INIT_PNG.cint

  assert sdl2.init(INIT_VIDEO) == SdlSuccess, $sdl2.getError()
  assert image.init(imgflags) == imgflags, $sdl2.getError()

  let window = glsupport.init(allRes) do () -> WindowPtr:
    createWindow("Renderer Example", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 
                 WW, WH, SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE)

  assert window != nil, $sdl2.getError()

  let surface = getSurface(window)
  assert surface != nil, $sdl2.getError()

  var gls = initGLState(window)
  var ts1 = initTileset(gls.rset, "platformertiles.png", 32)

  #showCursor(false)
  vfont.init()

  try:
    runLoop(gls, ts1)
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
