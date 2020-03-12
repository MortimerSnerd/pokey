## Common types and functions for components
## that need to handle input and drawing.
import
  glstate, glsupport, strformat

type
  Controller* = ref object of RootRef
    ## Set of functions needed to handle input and/or render.
    ## If any of the functions raises an exception, the controller
    ## will be removed, with a log message.
    ## There will be a stack of these, with the active Controller
    ## being the top of the stack.

    drawPrevious*: bool
      ## Should be set to true by the controller if previous
      ## controllers on the active stack should be drawn before
      ## a draw call for this controller.

    handleInput*: proc (c: Controller; dT: float) : InHandlerStatus
      ## Function that's called to deal with input.  Happens before
      ## drawing.  Can be nil if there's no input handling.
      
    draw*: proc (c: Controller; gls: var GLState; dT: float) 
      ## Responsible for drawing.  Should not assume it's the 
      ## only thing rendering, so no calls to swapWindow().

    activated*: proc (c: Controller)
      ## Called when the controller is activated, before any other 
      ## calls.  Can be nil.

    paused*: proc (c: Controller)
      ## Called when the controller is temporarily deactivated by
      ## another active controller being pushed on the stack. 
      ## Will be followed by an resumed() when this controller 
      ## becomes active again.  Can be nil.

    resumed*: proc (c: Controller)
      ## Called when the controller is reactivated after a pause.
      ## Can be nil.

    deactivated*: proc (c: Controller) 
      ## Called when the controller is popped off the stack of controllers.
      ## No other functions should be called after this, so good for
      ## final cleanup.  Can be nil.

  InHandlerStatus* = enum
    Running, 
    Finished     ## This controller is done.  If this is returned, the corresponding draw call
                  ## will not be called.

  ControllerManager* = object
    cs: seq[Controller]

proc processFrame*(cm: var ControllerManager; gls: var GLState; dT: float32) : bool = 
  ## Performs a single frame for the active controllers.  
  ## Returns false if the caller can exit, or if all controllers have been popped off
  ## the stack.
  let nc = len(cm.cs)
  if nc == 0:
    return false

  let cur = cm.cs[nc-1]

  try:
    if cur.handleInput != nil:
      case cur.handleInput(cur, dT)
      of Finished:
        if cur.deactivated != nil:
          cur.deactivated(cur)
        if nc > 1:
          let prev = cm.cs[nc-1]
          if prev.resumed != nil:
            prev.resumed(prev)
        discard pop(cm.cs)
        return true

      of Running:
        discard

    # If we're supposed to draw inactive controllers, 
    # find the earliest controller to start with.
    var cnum = nc - 1

    while cnum > 0 and cm.cs[cnum].drawPrevious:
      dec(cnum)

    # Now draw controllers in order.
    while cnum < nc:
      let ct = cm.cs[cnum]
      if ct.draw != nil:
        ct.draw(ct, gls, dT)
      inc(cnum)
      
  except:
    var e = getCurrentException()
    echo "Aborting active controller, exception escaped:"
    echo(&"{e.msg}\n{e.getStackTrace()}")

    if len(cm.cs) > 0:
      discard pop(cm.cs)

  return len(cm.cs) > 0

proc add*(cm: var ControllerManager; c: Controller)= 
  ## Pushes `c` on the controller stack, making it the active
  ## controller.
  assert c != nil
  let nc = len(cm.cs)

  if nc > 0 and cm.cs[nc-1].paused != nil:
      let cur = cm.cs[nc-1]
      cur.paused(cur)

  add(cm.cs, c)
  if c.activated != nil:
    c.activated(c)
        
