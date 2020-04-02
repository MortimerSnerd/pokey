## Helper functions for checking input events.
import
  sdl2 

type
  KMod* = enum
    ## We don't want to abstract over SDL, but
    ## using this for key modifier tests saves a lot of
    ## tedious bit testing.
    Control, Shift, Alt

func keyReleased*(ev: sdl2.Event; keycode: cint; mods: set[KMod]) : bool = 
  ## Is this a keyRelease event for the specified keysym?
  if ev.kind != KeyUp:
    return false

  if ev.key.keysym.sym != keycode:
    return false

  # Check for specified mods & absence of mods not specified.
  # Since there are separate bits for left and right control/alt
  # keys, we have to be picky about how we test this.
  template checkmod(kmod: KMod; modmask: cint) = 
    let ctrlm = ev.key.keysym.modstate and modmask

    if kmod in mods:
      if ctrlm == 0:
        return false
    else:
      if ctrlm != 0:
        return false

  checkmod(Control, KMOD_CTRL)
  checkmod(Shift, KMOD_SHIFT)
  checkmod(Alt, KMOD_ALT)

  return true

