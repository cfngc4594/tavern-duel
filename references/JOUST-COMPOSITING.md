# Joust in-play texture compositing

Source: https://github.com/HearthSim/Joust/tree/253e5770258f81ac9e7952f9a480e40a10f45d19

Downloaded original images: `joust/assets/images/`; renderer source: `joust/src/components/game/visuals/`; stylesheet: `joust/src/styles/entities.less`; SVG masks: `joust_clips`.

These are the repository's mappings, not independent measurements of the 2013/2014 client.

## Minion

Native canvas 300 x 350. Preserve this aspect ratio (source renderer uses width/height 0.86, nearly 300/350). Composite in this order:

1. `inplay_minion_taunt.png` if Taunt, full canvas. This is opaque shield art, so it must be behind the portrait.
2. Square portrait image: left 7% of canvas width, top 10% of canvas height, width/height 85% of canvas width. Native pixel rect (21,35,255,255).
3. Clip portrait in its own rect to ellipse center (0.51,0.50), radius (0.35,0.46). Native canvas ellipse center (151.05,162.5), radius (89.25,117.3).
4. `inplay_minion.png` full canvas (includes attack and health gems), or `inplay_minion_hide_stats.png` without gems.
5. Legendary frame and state layers if relevant. Icons, sleep, damage layers follow.

Stats source CSS: attack left 19.75%, health left 59.75%, both top 63.5%. Each text div width 20% of canvas, centered. Thus horizontal centers = 29.75% and 69.75% (89.25px,209.25px). The top is a text box top, not text baseline or center. White text with 1px black outline; buff green #29dd4f, damage red #dd0000.

## Hero

Native square canvas 280 x 280.
1. Square portrait rect left 7%, top 9%, height/width 82% => (19.6,25.2,229.6,229.6).
2. Clip its local UV to polygon [(0,1),(0,.4),(.2,.1),(.3,.03),(.5,0),(.7,.03),(.8,.1),(1,.4),(1,1)].
3. `hero_frame.png` full canvas; optional hero_attack/hero_armor same full canvas.

Health box left 74%, top 81.5%, width 20% => horizontal center 84% (235.2px). Armor left74%, top56%; attack left5.5%, top81.5%.

## Hero power

Native square canvas 250 x250.
1. Square art rect left23%, top27%, width/height55% => (57.5,67.5,137.5,137.5).
2. Clip local art to circle center(.5,.5), radius .6 (the frame covers excess).
3. `hero_power.png` full canvas, or `hero_power_exhausted.png` which covers portrait with closed brown spiral.

Cost text box left40%, top4%, width20%, centered (horizontal center50%).

## Mana and text

`mana_crystal.png` is the standalone game-style crystal. Joust uses full brightness for full; brightness50% for spent; grayscale100% for locked. Stylesheet has no original tray texture.

Source fonts in variables.less: `belwe_fsextrabold` and `franklin_gothic_fsMdCn`. They are referenced but NOT bundled; the only font binaries in Joust are FontAwesome.

## Copyright and historical limits

Joust README explicitly reserves HearthSim code rights and states some textures copyright Blizzard. Downloading or reading is not redistribution permission. The in-play minion/taunt file histories end 2016-02-20; hero power 2016-02-18; hero frame 2016-02-23. Exact 2013/2014 game-client build is unverified.
