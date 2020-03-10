## Common openGL related state.
import
  geom, glsupport, opengl, verts

type
  GLState* = object
    rset*: ResourceSet ## Resource set that controls the lifetime of the GL objects created here.
    uni*: StdUniforms ## Our in memory copy of the uniforms.
    uniblk*: BufferObject ## Buffer object for the uniforms.
    indices*, vtxs*: BufferObject ## Buffer objects for geometry.
    colorb*: VertBatch[VtxColor,uint16] ## buffering for VtxColor vertices, so we can push batches out to `indices` & `vtxs`.
    solidColor*: Program ## Shader for rendering of solid per vertex colors.

proc initGLState*() : GLState {.raises: [GLError,ValueError,IOError].} = 
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

  glBindBufferBase(GL_UNIFORM_BUFFER, StdUniformsBinding, result.uniblk.handle)
  glEnable(GL_CULL_FACE)
  glDepthFunc(GL_LESS)

