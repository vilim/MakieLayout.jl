function LRangeSlider(parent::Scene; bbox = nothing, kwargs...)

    attrs = merge!(Attributes(kwargs), default_attributes(LSlider))

    decorations = Dict{Symbol, Any}()

    @extract attrs (
        halign, valign, linewidth, buttonradius, horizontal,
        startvalues, value, color_active, color_active_dimmed, color_inactive,
        buttonstrokewidth, buttoncolor_inactive
    )

    sliderrange = attrs.range

    sizeattrs = sizenode!(attrs.width, attrs.height)
    alignment = lift(tuple, halign, valign)

    autosizenode = lift(buttonradius, horizontal, buttonstrokewidth, typ=NTuple{2, Optional{Float32}}) do br, hori, bstrw
        if hori
            (nothing, 2 * (br + bstrw))
        else
            (2 * (br + bstrw), nothing)
        end
    end

    suggestedbbox = create_suggested_bboxnode(bbox)

    computedsize = computedsizenode!(sizeattrs, autosizenode)

    finalbbox = alignedbboxnode!(suggestedbbox, computedsize, alignment, sizeattrs, autosizenode)

    subarea = lift(finalbbox) do bbox
        IRect2D(bbox)
    end
    subscene = Scene(parent, subarea, camera=campixel!)

    sliderbox = lift(bb -> Rect{2, Float32}(zeros(eltype(bb.origin), 2), bb.widths), finalbbox)

    endpoints = lift(sliderbox, horizontal) do bb, horizontal

        if horizontal
            y = bottom(bb) + height(bb) / 2
            [Point2f0(left(bb), y),
            Point2f0(right(bb), y)]
        else
            x = left(bb) + width(bb) / 2
            [Point2f0(x, bottom(bb)),
            Point2f0(x, top(bb))]
        end
    end

    selected_indices = Node([1, length(sliderrange)])

    # the fraction on the slider corresponding to the selected_indices
    # this is only used after dragging_left
    sliderfractions = lift(selected_indices, sliderrange) do i, r
        (i .- 1) ./ (length(r) - 1)
    end

    dragging_left = Node(false)
    dragging_right = Node(false)

    # what the slider actually displays
    displayed_sliderfraction = Node([0.0, 1.0])

    on(sliderfractions) do frac
        # only update displayed fraction through sliderfraction if not dragging_left
        # dragging_left overrides the value so there is clear mouse interaction
        if !dragging_left[]
            displayed_sliderfraction[][1] = frac[1]
        end
        if !dragging_right[]
            displayed_sliderfraction[][2] = frac[2]
        end

    end

    on(selected_indices) do (i, j)
        value[] = (sliderrange[][i], sliderrange[][j])
    end

    # initialize slider value with closest from range
    selected_indices[] = closest_index.(Ref(sliderrange[]), startvalues[])

    buttonpoints = lift(sliderbox, horizontal, displayed_sliderfraction, buttonradius,
            buttonstrokewidth) do bb, horizontal, sf, brad, bstw

        pad = brad + bstw

        if horizontal
            [Point2f0(left(bb) + pad + (width(bb) - 2pad) * sf[1], bottom(bb) + height(bb) / 2),
             Point2f0(left(bb) + pad + (width(bb) - 2pad) * sf[2], bottom(bb) + height(bb) / 2)]
        else
            [Point2f0(left(bb) + 0.5f0 * width(bb), bottom(bb) + pad + (height(bb) - 2pad) * sf[1]),
             Point2f0(left(bb) + 0.5f0 * width(bb), bottom(bb) + pad + (height(bb) - 2pad) * sf[2])]
        end
    end

    linepoints = lift(endpoints, buttonpoints) do eps, bp
        [eps[1], bp[1], bp[1], bp[2], bp[2], eps[2]]
    end

    linecolors = lift(color_active_dimmed, color_inactive) do ca, ci
        [ci, ca, ci]
    end

    linesegs = linesegments!(subscene, linepoints, color = linecolors, linewidth = linewidth, raw = true)[end]

    linestate = addmousestate!(subscene, linesegs)

    bsize = Node{Float32}(buttonradius[] * 2f0)

    bcolor = Node{Any}(buttoncolor_inactive[])

    button = scatter!(subscene, buttonpoints, markersize = bsize, color = bcolor,
        strokewidth = buttonstrokewidth, strokecolor = color_active_dimmed, raw = true)[end]

    buttonstate = addmousestate!(subscene, button)

    # on(buttonstate) do state
    #     typ = typeof(state.typ)
    #     if typ in (MouseDown, MouseDrag, MouseDragStart, MouseDragStop)
    #         bcolor[] = color_active[]
    #     end
    # end

    onmouseleftdown(buttonstate) do state
        bcolor[] = color_active[]
    end

    onmouseleftup(buttonstate) do state
        bcolor[] = buttoncolor_inactive[]
    end

    onmouseleftdrag(buttonstate) do state

        pad = buttonradius[] + buttonstrokewidth[]

        if abs(state.prev - displayed_sliderfraction[][1]) < abs(state.prev - displayed_sliderfraction[][2])
            dragging_left[] = true
        else
            dragging_right[] = true
        end
        dif = state.pos - state.prev
        fraction = if horizontal[]
            dif[1] / (width(sliderbox[]) - 2pad)
        else
            dif[2] / (height(sliderbox[]) - 2pad)
        end
        if fraction != 0.0f0
            @async begin
                idx_sel = dragging_left[] ? 1 : 2
                
                newfraction = min(max(displayed_sliderfraction[][idx_sel] + fraction, 0f0), 1f0)
                displayed_sliderfraction[][idx_sel] = newfraction
                displayed_sliderfraction[] = displayed_sliderfraction[]

                newindex = closest_fractionindex(sliderrange[], newfraction)
                if selected_indices[][idx_sel] != newindex
                    selected_indices[][idx_sel] = newindex
                    selected_indices[] = selected_indices[]
                end
            end
        end
    end

    onmouseleftdragstop(buttonstate) do state
        dragging_left[] = false
        dragging_right[] = false
        # adjust slider to closest legal value
        sliderfraction[] = sliderfraction[]
    end

    scenestate = addmousestate!(subscene)

    onmouseleftclick(scenestate) do state

        pad = buttonradius[] + buttonstrokewidth[]

        pos = state.pos
        dim = horizontal[] ? 1 : 2
        frac = (pos[dim] - endpoints[][1][dim] - pad) / (endpoints[][2][dim] - endpoints[][1][dim] - 2pad)
        selected_indices[] = closest_fractionindex(sliderrange[], frac)
    end

    onmouseleftdoubleclick(scenestate) do state
        selected_indidices[] = closest_index.(Ref(sliderrange[]), startvalues[])
    end

    onmouseenter(scenestate) do state
        # bcolor[] = color_active[]
        linecolors[] = [color_active[], color_inactive[]]
        button.strokecolor = color_active[]
    end

    onmouseout(scenestate) do state
        # bcolor[] = color_inactive[]
        linecolors[] = [color_active_dimmed[], color_inactive[]]
        button.strokecolor = color_active_dimmed[]
    end

    protrusions = lift(buttonradius, horizontal) do br, horizontal
        if horizontal
            RectSides{Float32}(br, br, 0, 0)
        else
            RectSides{Float32}(0, 0, br, br)
        end
    end

    layoutnodes = LayoutNodes{LRangeSlider, GridLayout}(suggestedbbox, protrusions, computedsize, autosizenode, finalbbox, nothing)

    # trigger bbox
    suggestedbbox[] = suggestedbbox[]

    LRangeSlider(parent, layoutnodes, attrs, decorations)
end

function valueindex(sliderrange, value)
    for (i, val) in enumerate(sliderrange)
        if val == value
            return i
        end
    end
    nothing
end

function closest_fractionindex(sliderrange, fraction)
    n = length(sliderrange)
    onestepfrac = 1 / (n - 1)
    i = round(Int, fraction / onestepfrac) + 1
    min(max(i, 1), n)
end

function closest_index(sliderrange, value)
    distance = Inf
    selected_i = 0
    for (i, val) in enumerate(sliderrange)
        newdist = abs(val - value)
        if newdist < distance
            distance = newdist
            selected_i = i
        end
    end
    selected_i
end
