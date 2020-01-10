using Makie
using MakieLayout

scene, layout = layoutscene(1, 1, 30)

slider = layout[1, 1] = LRangeSlider(scene)

display(scene)