import 
  comalg, glstate, glsupport, geom, opengl, platform, sdl2, sdl2/image, 
  strformat, verts, vfont, zstats

const
  WW=800
  WH=480

proc runLoop(gls: GLState, window: WindowPtr) = 
  var running = true

  while running:
    glClearColor(0, 0, 0, 0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

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
  let gls = newGLState()

  showCursor(false)
  vfont.init()

  try:
    runLoop(gls, window)
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
