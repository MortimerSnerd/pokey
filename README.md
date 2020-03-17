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
