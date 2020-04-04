## Implementation glue for microui + utility functions.
import 
  comalg, glstate, glsupport, geom, math, microui, opengl, sdl2, 
  strformat, tilesets, verts, vfont

const TextScale = 1.0

type
  UIContext* = object 
    ctx: ptr mu_Context
    icons: Tileset

proc vfont_text_width(font: mu_Font, text: cstring, len: cint) : cint {.cdecl.} = 
  cint(ceil(textWidth($text, TextScale)))

proc vfont_text_height(font: mu_Font) : cint {.cdecl.} = 
  cint(ceil(fontHeight(TextScale)))

proc init*(rset: var ResourceSet; file: string; gridDim: Positive = 16) : UIContext = 
  ## Initializes the module, and returns a context for creating UIs.
  ## ``file`` is the image atlas that has the icon images defined.
  let ctx = create(mu_Context, 1)
  mu_init(ctx)
  ctx.text_width = vfont_text_width
  ctx.text_height = vfont_text_height

  #ctx.style.colors[MU_COLOR_BORDER] = mu_Color(r: 0, g: 255, b: 0, a: 255)
  return UIContext(ctx: ctx, 
                   icons: initTileset(rset, file, gridDim))

proc destroy*(c: var UIContext) = 
  ## Should be called to release the context when you're done with it.
  if c.ctx != nil:
    dealloc(c.ctx)

  # Don't bother with the tileset, the GL resources are handled by a
  # ``ResourceSet``.

proc glColor(c: mu_Color) : V4f = 
  (c.r.float32 / 255.0f, c.g.float32/255.0f, c.b.float32/255.0f, c.a.float32/255.0f)

proc render*(c: var UIContext; gls: var GLState) = 
  ## After all mu_calls are made for a UI, this can be called to render
  ## everything.
  var cmd: ptr mu_Command

  fullScreenOrtho(gls)
  setUniforms(gls)
  glEnable(GL_SCISSOR_TEST)

  #echo "STARRR"
  while mu_next_command(c.ctx, addr cmd) != 0:
    case cmd.`type`
    of MU_COMMAND_TEXT:
      #echo &"TEXT {cmd.text}"
      clear(gls.colorb)
      drawingLines(gls, {Submit}):
        text(gls.colorb, $cast[cstring](addr cmd.text.str[0]), vec2(float32(cmd.text.pos.x), float32(cmd.text.pos.y)), TextScale, 
             cmd.text.color.glColor)

    of MU_COMMAND_RECT:
      #echo &"RECT {cmd.rect}"
      let tl = vec2(float32(cmd.rect.rect.x), float32(cmd.rect.rect.y))
      let br = tl + vec2(float32(cmd.rect.rect.w), float(cmd.rect.rect.h))
      let color = glColor(cmd.rect.color)

      clear(gls.colorb)
      triangulate(gls.colorb, [
        VtxColor(pos: tl, color: color), 
        VtxColor(pos: (br.x, tl.y), color: color), 
        VtxColor(pos: br, color: color), 
        VtxColor(pos: (tl.x, br.y), color: color)
      ])
      glEnable(GL_BLEND)
      use(gls.solidColor)
      bindAndConfigureArray(gls.vtxs, VtxColorDesc)
      submitAndDraw(gls.colorb, gls.vtxs, gls.indices, GL_TRIANGLES)

    of MU_COMMAND_CLIP:
      #echo &"CLIP {cmd.clip}"
      let rect = addr cmd.clip.rect

      glScissor(rect.x, gls.wHi - (rect.y + rect.h), rect.w, rect.h);

    of MU_COMMAND_ICON:
      #echo &"ICON {cmd.icon}"
      withTileset(c.icons, gls):
        let dest = (float32(cmd.icon.rect.x), float32(cmd.icon.rect.y)) @ (float32(cmd.icon.rect.w), float32(cmd.icon.rect.h))
        draw(c.icons, gls.txbatch3, cmd.icon.id - 1, dest)
        submitAndDraw(gls.txbatch3, gls.vtxs, gls.indices, GL_TRIANGLES)

    else:
      #echo &"WOT {cmd.`type`}"
      discard

  glDisable(GL_SCISSOR_TEST)

proc sdlbutton_to_mu(button: uint8) : cint = 
  let bb = SDL_BUTTON(button)
  if bb == BUTTON_LEFT:
    MU_MOUSE_LEFT
  elif bb == BUTTON_MIDDLE:
    MU_MOUSE_MIDDLE
  elif bb == BUTTON_RIGHT:
    MU_MOUSE_RIGHT
  else:
    -1

let ctrlkeys = [
  (K_LSHIFT, cint(MU_KEY_SHIFT)), 
  (K_RSHIFT, cint(MU_KEY_SHIFT)), 
  (K_LCTRL, cint(MU_KEY_CTRL)), 
  (K_RCTRL, cint(MU_KEY_CTRL)), 
  (K_LALT, cint(MU_KEY_ALT)),
  (K_RALT, cint(MU_KEY_ALT)), 
  (K_RETURN, cint(MU_KEY_RETURN)), 
  (K_BACKSPACE, cint(MU_KEY_BACKSPACE))
]

proc windowContainsPoint*(uc: UIContext; x, y: cint) : bool =
  ## Can be uses to check to see if the mouse is over a window, to 
  ## see if we need to send an event to feed().  Only necessary because
  ## microui only handles part of the screen.
  for i in 0..<uc.ctx.root_list.idx:
    if uc.ctx.root_list.items[i].open != 0:
      let r = addr uc.ctx.root_list.items[i].rect;
      let bl = mu_Vec2(x: r.x + r.w, y: r.y + r.h)

      if x >= r.x and x < bl.x and y >= r.y and y < bl.y:
        return true

  return false

proc feed*(c: UIContext; ev: sdl2.Event) = 
  ## Whenever a UI is active, this should be called for any SDL2 events
  ## that the caller hasn't handled themselves.
  case ev.kind
  of MouseMotion:
    mu_input_mousemove(c.ctx, ev.motion.x, ev.motion.y)

  of MouseWheel:
    mu_input_scroll(c.ctx, 0, ev.wheel.y * -30)

  of TextInput:
    mu_input_text(c.ctx, addr ev.text.text[0])

  of MouseButtonDown:
    let mbut = sdlbutton_to_mu(ev.button.button)

    if mbut >= 0:
      mu_input_mousedown(c.ctx, ev.button.x, ev.button.y, mbut)

  of MouseButtonUp:
    let mbut = sdlbutton_to_mu(ev.button.button)

    if mbut >= 0:
      mu_input_mouseup(c.ctx, ev.button.x, ev.button.y, mbut)

  of KeyUp:
    let i = linearIndex(ctrlkeys, ev.key.keysym.sym)
    if i >= 0:
      mu_input_keyup(c.ctx, ctrlkeys[i][1])

  of KeyDown:
    let i = linearIndex(ctrlkeys, ev.key.keysym.sym)
    if i >= 0:
      mu_input_keydown(c.ctx, ctrlkeys[i][1])

  else:
    discard

converter ctxaccess*(u: UIContext) : ptr mu_Context = u.ctx

proc mu_draw_text*(ctx: ptr mu_Context; font: mu_Font; str: string;
                  pos: mu_Vec2; color: mu_Color) = 
  ## Helper with no extra string length parameter for nim strings.
  mu_draw_text(ctx, font, str, cint(len(str)), pos, color)

proc brRect*(gls: GLState; w, h: cint) : mu_Rect = 
  ## Returns a rectangle for the bottom right of the screen, with
  ## the given dimensions.
  mu_Rect(x: gls.wWi - w, y: gls.wHi - h, w: w, h: h)

proc blRect*(gls: GLState; w, h: cint) : mu_Rect = 
  ## Returns rectangle for bottom left of screen with the
  ## given dimesions.
  mu_Rect(x: 0, y: gls.wHi - h, w: w, h: h)

proc centeredRect*(gls: GLState; w, h: cint) : mu_Rect = 
  ## Returns rectangle centered on the screen.
  let cp = vec2(gls.wWi div 2, gls.wHi div 2)
  let hw = w div 2
  let hh = h div 2

  mu_Rect(x: cp.x - hw, y: cp.y - hh, w: w, h: h)

proc layout_row*(ui: var UIContext; rows: openarray[cint]; height: cint) = 
  ## Helper to reduce clutter of decls needed to call mu_layout_row
  mu_layout_row(ui.ctx, len(rows).cint, unsafeAddr rows[0], height)

## TODO a proc to register a texture and srcRect as an "icon", and return an id for it that
## can be passed into mu_* functions.
