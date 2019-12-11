function LLegend(parent::Scene; bbox = nothing, kwargs...)

    attrs = merge!(Attributes(kwargs), default_attributes(LLegend))

    @extract attrs (
        halign, valign, padding, margin,
        title, titlefont, titlesize, titlealign,
        labelsize, labelfont, labelcolor, labelhalign, labelvalign,
        bgcolor, strokecolor, strokewidth,
        patchsize, # the side length of the entry patch area
        ncols,
        colgap, rowgap, patchlabelgap,
    )

    decorations = Dict{Symbol, Any}()

    sizeattrs = sizenode!(attrs.width, attrs.height)
    alignment = lift(tuple, halign, valign)

    suggestedbbox = create_suggested_bboxnode(bbox)

    autosizenode = Node((500f0, 500f0))

    computedsize = computedsizenode!(sizeattrs, autosizenode)

    finalbbox = alignedbboxnode!(suggestedbbox, computedsize, alignment, sizeattrs)

    scenearea = @lift(IRect2D($finalbbox))

    scene = Scene(parent, scenearea, raw = true, camera = campixel!)

    translate!(scene, (0, 0, 10))

    legendrect = @lift(
        BBox($margin[1], width($scenearea) - $margin[2],
             $margin[3], height($scenearea)- $margin[4]))

    frame = poly!(scene,
        @lift(enlarge($legendrect, repeat([-$strokewidth/2], 4)...)),
        color = bgcolor, strokewidth = strokewidth,
        strokecolor = strokecolor, raw = true)[end]

    entries = Node(LegendEntry[])


    maingrid = GridLayout(legendrect, alignmode = Outside(20))
    manipulating_grid = Ref(false)

    onany(maingrid.needs_update, margin) do _, margin
        if manipulating_grid[]
            return
        end
        w = determinedirsize(maingrid, Col())
        h = determinedirsize(maingrid, Row())
        if !any(isnothing.((w, h)))
            autosizenode[] = (w + sum(margin[1:2]), h + sum(margin[3:4]))
        end
    end

    entrytexts = LText[]
    entryplots = [AbstractPlot[]]
    entryrects = LRect[]

    titletext = maingrid[1, 1] = LText(scene, text = title, textsize = titlesize, halign = titlealign)

    labelgrid = maingrid[2, 1] = GridLayout()

    function relayout()
        manipulating_grid[] = true

        n_entries = length(entries[])
        nrows = ceil(Int, n_entries / ncols[])

        # the grid has twice as many columns as ncols, because of labels and patches
        ncols_with_symbolcols = 2 * min(ncols[], n_entries) # if fewer entries than cols, not so many cols

        for (i, lt) in enumerate(entrytexts)
            irow = (i - 1) ÷ ncols[] + 1
            icol = (i - 1) % ncols[] + 1
            labelgrid[irow, icol * 2] = lt
        end

        for (i, rect) in enumerate(entryrects)
            irow = (i - 1) ÷ ncols[] + 1
            icol = (i - 1) % ncols[] + 1
            labelgrid[irow, icol * 2 - 1] = rect
        end
        # this is empty if no superfluous rows exist
        # for i in length(entrytexts) : -1 : (length(entries[]) + 1)
        #     # remove object from scene
        #     remove!(entrytexts[i])
        #     # remove reference from array
        #     deleteat!(entrytexts, i)
        # end

        for i in labelgrid.nrows : -1 : max((nrows + 1), 2) # not the last row
            deleterow!(labelgrid, i)
        end

        for i in labelgrid.ncols : -1 : max((ncols_with_symbolcols + 1), 2) # not the last col
            deletecol!(labelgrid, i)
        end

        for i in 1:(labelgrid.ncols - 1)
            if i % 2 == 1
                colgap!(labelgrid, i, Fixed(patchlabelgap[]))
            else
                colgap!(labelgrid, i, Fixed(colgap[]))
            end
        end

        for i in 1:(labelgrid.nrows - 1)
            rowgap!(labelgrid, i, Fixed(rowgap[]))
        end

        manipulating_grid[] = false
        maingrid.needs_update[] = true

        translate!(scene, (0, 0, 10))
    end

    onany(ncols, rowgap, colgap, patchlabelgap) do _, _, _, _; relayout(); end

    on(entries) do entries

        # first delete all existing labels and patches

        # delete from grid layout
        detachfromgridlayout!.(entrytexts, Ref(labelgrid))
        # and from scene
        delete!.(entrytexts)
        empty!(entrytexts)

        # delete from grid layout
        detachfromgridlayout!.(entryrects, Ref(labelgrid))
        # and from scene
        delete!.(entryrects)
        empty!(entryrects)

        # delete patch plots
        for eplots in entryplots
            # each entry can have a vector of patch plots
            delete!.(scene, eplots)
        end
        empty!(entryplots)

        # the attributes for legend entries that the legend itself carries
        # these serve as defaults unless the legendentry gets its own value set
        preset_attrs = extractattributes(attrs, LegendEntry)

        for (i, e) in enumerate(entries)

            # lift attributes from the legend if the entry doesn't have them
            for a in attributenames(LegendEntry)
                if !haskey(e.attributes, a)
                    setindex!(e.attributes, lift(x -> x, preset_attrs[a]), a)
                end
            end

            # create the label
            push!(entrytexts, LText(scene,
                text = e.label, textsize = e.labelsize, font = e.labelfont,
                color = e.labelcolor, halign = e.labelhalign, valign = e.labelvalign
                ))

            # create the patch rectangle
            rect = LRect(scene, color = e.patchcolor, strokecolor = e.patchstrokecolor,
                strokewidth = e.patchstrokewidth,
                width = lift(x -> x[1], e.patchsize),
                height = lift(x -> x[2], e.patchsize))
            push!(entryrects, rect)

            # plot the symbols belonging to this entry
            symbolplots = AbstractPlot[
                legendsymbol!(scene, element, rect.layoutnodes.computedbbox, e.attributes)
                for element in e.elements]

            push!(entryplots, symbolplots)
        end
        relayout()
    end

    # entries[] = [
    #     LegendEntry("entry 1", AbstractPlot[]),
    # ]

    # no protrusions
    protrusions = Node(RectSides(0f0, 0f0, 0f0, 0f0))

    # trigger suggestedbbox
    suggestedbbox[] = suggestedbbox[]

    layoutnodes = LayoutNodes(suggestedbbox, protrusions, computedsize, finalbbox)

    LLegend(scene, entries, layoutnodes, attrs, decorations, entrytexts, entryplots)
end


function legendsymbol!(scene, element::MarkerElement, bbox, attrs::Attributes)
    fracpoints = attrs.markerpoints
    points = @lift(fractionpoint.(Ref($bbox), $fracpoints))
    scatter!(scene, points, color = element.color, marker = element.marker,
        markersize = (haskey(element.attributes, :markersize) ? element.markersize : attrs.markersize),
        strokewidth = attrs.markerstrokewidth,
        strokecolor = element.strokecolor, raw = true)[end]
end

function legendsymbol!(scene, element::LineElement, bbox, attrs::Attributes)
    fracpoints = attrs.linepoints
    points = @lift(fractionpoint.(Ref($bbox), $fracpoints))
    lines!(scene, points, linewidth = 3f0, color = element.color,
        linestyle = element.linestyle,
        raw = true)[end]
end

function Base.getproperty(lentry::LegendEntry, s::Symbol)
    if s in fieldnames(LegendEntry)
        getfield(lentry, s)
    else
        lentry.attributes[s]
    end
end

function Base.setproperty!(lentry::LegendEntry, s::Symbol, value)
    if s in fieldnames(LegendEntry)
        setfield!(lentry, s, value)
    else
        lentry.attributes[s][] = value
    end
end

function Base.propertynames(lentry::LegendEntry)
    [fieldnames(T)..., keys(lentry.attributes)...]
end

# function LegendEntry(label::String, plot::AbstractPlot, plots...; kwargs...)
#     attrs = Attributes(label = label)
#     merge!(attrs, Attributes(kwargs))
#
#     # don't merge here, include missing ones later when inserted into the legend
#     # because the main settings should be in the legend
#     # merge!(attrs, default_attributes(LLegend))
#
#     LegendEntry(AbstractPlot[plot, plots...], attrs)
# end

# function legendsymbol!(scene, plot::Union{Lines, LineSegments}, bbox)
#     fracpoints = [Point2f0(0, 0.5), Point2f0(1, 0.5)]
#     points = @lift(fractionpoint.($bbox, fracpoints))
#     lines!(scene, points)[end]
# end
function LegendEntry(label::String, plots::Vararg{AbstractPlot}; kwargs...)
    attrs = Attributes(label = label)

    kwargattrs = Attributes(kwargs)
    merge!(attrs, kwargattrs)

    elems = vcat(legendelements.(plots)...)
    LegendEntry(elems, attrs)
end

function LegendEntry(label::String, elements::Vararg{LegendElement}; kwargs...)
    attrs = Attributes(label = label)

    kwargattrs = Attributes(kwargs)
    merge!(attrs, kwargattrs)

    elems = LegendElement[elements...]
    LegendEntry(elems, attrs)
end

function LineElement(;kwargs...)
    LineElement(Attributes(kwargs))
end

function MarkerElement(;kwargs...)
    MarkerElement(Attributes(kwargs))
end
function PatchElement(;kwargs...)
    PatchElement(Attributes(kwargs))
end

function legendelements(plot::Union{Lines, LineSegments})
    LegendElement[LineElement(color = plot.color, linestyle = plot.linestyle)]
end

function legendelements(plot::Scatter)
    LegendElement[MarkerElement(
        color = plot.color, marker = plot.marker,
        strokecolor = plot.strokecolor)]
end

function legendelements(plot::Poly)
    LegendElement[PatchElement(color = plot.color, strokecolor = plot.strokecolor)]
end

function Base.getproperty(legendelement::T, s::Symbol) where T <: LegendElement
    if s in fieldnames(T)
        getfield(legendelement, s)
    else
        legendelement.attributes[s]
    end
end

function Base.setproperty!(legendelement::T, s::Symbol, value) where T <: LegendElement
    if s in fieldnames(T)
        setfield!(legendelement, s, value)
    else
        legendelement.attributes[s][] = value
    end
end

function Base.propertynames(legendelement::T) where T <: LegendElement
    [fieldnames(T)..., keys(legendelement.attributes)...]
end