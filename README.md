## What is this

Hell if I know.  Right now it's just a small project to play with SDL2 
and OpenGL with.  Using the latest Nim devel branch.

I did half-heartedly try to compile with --gc:arc to see how that is 
coming along, but didn't feel like chasing down the errors in printing 
unsigned ints in the v2 repr implementation just yet.

## Build notes

With all of the submodules pulled, ``nim build`` to build it.

To regenerate `src/microui.nim`, apply the `vendor/microui-c2nim.patch` to 
the microui header file.  This adds a couple of things to help c2nim to translate 
the header cleanly.  I hand modified ``mu_Color`` in the resulting file to have
`byte` members rather than `cuchar`, so the compiler won't complain about 
assigning integers to the fields. 

## TODO

- Coalesce BlocksCharacter into rects for Blockset

- Fill out level object.
  - multiple layers
    - layers can have tint and a scaling for parallax scrolling.
  - Add editor that allows placement of blocksets into a layer
    - Snap to grid for 32, 16, 8, 4, 2, 1 in a control somewhere.

- add simple char, and have it:
  - move
  - fall
  - collide with BlockCharacter rects from the Blocksets

✓ TTF font support
  ~~- Previously, have used guillotine partitioning to 
    divide up a texture into areas the TTF library can
    cache into.  It can be a little complicated, and can 
    have interesting fragmentation issues.~~
  ✓ Change ui support to use ttf fonts instead of debug vector fonts. 
  ✓ Possible simplification 1: Have a per-font/size glyph
    cache, that we subdivide vertically into font-height 
    strips.  Letters go into those as we encounter them. 
    No expectatation that a character will be removed from 
    the cache, so no book-keeping to deal with that for 
    non-monospaced fonts.  Slightly more complicated than 
    just generating a bitmap font from a TTF, but allows chars
    we didn't anticipate.
  - Add escapes and change buffers so coloring can change within a text?
  ~~- Possible simplification 2: Cache sentences, but using same
    per font/size cache with a texture vertically divided 
    into font-height strips. Perhaps more efficient, but more
    bookkeeping needs to be done, as pieces of text will be 
    expiring constantly.~~
