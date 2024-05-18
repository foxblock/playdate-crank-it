# Crank-It! for Playdate
![video](https://s10.gifyu.com/images/Sf3mQ.gif)

A game inspired by Bop-It for the Playdate. Written entirely in Lua.

## Get started
Basically follow [the official guide](https://sdk.play.date/2.4.2/Inside%20Playdate.html#_writing_a_game).

1. Install the [SDK](https://play.date/dev/)
1. `cd` into this folder
1. `pdc Source crank-it.pdx` to compile
1. Launch the Playdate Simulator app included in the SDK and open the compiled .pdx file
1. [Use Sideloading](https://play.date/account/sideload/)

For VSCode I recommend the [Playdate Debug](https://github.com/midouest/vscode-playdate-debug) extension, which enables running and full-featured debugging right in VSCode with the press of a button (available in the extension store).

## License
See [LICENSE.txt](LICENSE.txt)

### TL;DR
You may use the source-code and assets for your personal (or even commercial!) projects!  
Just make sure to credit me and the other original authors!  
Please don't release the work as-is in your own name, that would be weird.

## Useful stuff in here (maybe)
All of these should work as a single-file drop-in (except for the font, which is two files), since they don't have dependencies other than the SDK.

- [The Party font](Source/images/font): Comic Sans-esque font used in the game (also with bad kerning! although I tried my best, until I ran out of patience)
- [transition.lua](Source/transition.lua): Animation when switching from one scene to another with a diagonal swipe.
- [particles.lua](Source/particles.lua): Dynamic physics-influenced, image-based particles based on the SDK's Sprite system. Particles can be added with one line of code. Physics constants can be easily configured.
- [vec3d.lua](Source/vec3d.lua): 3D Vector math functions length, normalize and dotProduct (since the SDK only provides 2D versions).