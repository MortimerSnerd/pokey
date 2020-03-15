## Common openGL related state.
import
  geom, glsupport, opengl, sdl2, verts

type
  GLState* = object
    rset*: ResourceSet ## Resource set that controls the lifetime of the GL objects created here.
    uni*: StdUniforms ## Our in memory copy of the uniforms.
    uniblk*: BufferObject ## Buffer object for the uniforms.
    indices*, vtxs*: BufferObject ## Buffer objects for geometry.
    colorb*: VertBatch[VtxColor,uint16] ## buffering for VtxColor vertices, so we can push batches out to `indices` & `vtxs`.
    txbatch3*: VertBatch[TxVtx,uint16] ## for textured shapes.
    solidColor*: Program ## Shader for rendering of solid per vertex colors.
    txShader*: Program ## Basic textured shader, TxVtx in.
    wW*, wH*: float32 ## Window width and height.  Updated per frame.
    wWi*, wHi*: cint   ## Window width and height, int.
    window*: WindowPtr

proc initGLState*(win: WindowPtr) : GLState {.raises: [GLError,ValueError,IOError].} = 
  ## Creates and initializes a GLState object.
  result.uniblk = newBufferObject(result.rset)
  result.uni = StdUniforms(
    mvp: identity3d[float32](), 
    tint: WhiteG,
    cameraWorldPos: (0.0f, 0.0f, 0.0f, 1.0f))
  result.indices = newBufferObject(result.rset)
  result.vtxs = newBufferObject(result.rset)
  result.colorb = newVertBatch[VtxColor,uint16]()
  result.solidColor = newProgram(result.rset, 
                                 [newShaderFromFile(result.rset, "color2d.vtx", GL_VERTEX_SHADER), 
                                  newShaderFromFile(result.rset, "color2d.frag", GL_FRAGMENT_SHADER)])
  result.txbatch3 = newVertBatch[TxVtx,uint16]()
  result.txShader = newProgram(result.rset, 
                               [newShaderFromFile(result.rset, "basic_textured.vtx", GL_VERTEX_SHADER), 
                                newShaderFromFile(result.rset, "basic_textured.frag", GL_FRAGMENT_SHADER)])
  result.window = win;

  glBindBufferBase(GL_UNIFORM_BUFFER, StdUniformsBinding, result.uniblk.handle)
  glEnable(GL_CULL_FACE)
  glDepthFunc(GL_LESS)


proc frameStart*(gls: var GLState) = 
  ## Needs to be called at the beginning of each frame 
  sdl2.getSize(gls.window, gls.wWi, gls.wHi)
  gls.wW = float32(gls.wWi)
  gls.wH = float32(gls.wHi)

proc fullScreenOrtho*(gls: var GLState) = 
  gls.uni.mvp = orthoProjectionYDown[float32](0, gls.wW, 0, gls.wH, -2, 2)

proc setUniforms*(gls: var GLState) = 
  populate(gls.uniblk, GL_UNIFORM_BUFFER, gls.uni.addr, GL_DYNAMIC_DRAW)


type DrawingOption* = enum
  Submit

template drawingLines*(gls: var GLState; options: set[DrawingOption]; body: untyped) = 
  use(gls.solidColor)
  bindAndConfigureArray(gls.vtxs, VtxColorDesc)
  clear(gls.colorb)
  body

  if Submit in options:
    submitAndDraw(gls.colorb, gls.vtxs, gls.indices, GL_LINES)
