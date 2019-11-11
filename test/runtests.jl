using MakieLayout
using Makie
using KernelDensity
using FreeTypeAbstraction


boldface = newface(expanduser("~/Library/Fonts/SFHelloSemibold.ttf"))

function kdepoly!(scene, vec, scalevalue, reverse=false; kwargs...)
    kderesult = kde(vec; npoints=32)

    x = kderesult.x
    y = kderesult.density
    y = y .* (1 / maximum(y)) .* scalevalue

    if reverse
        poly!(scene, Point2.(y, x); kwargs...)[end]
    else
        poly!(scene, Point2.(x, y); kwargs...)[end]
    end
end

begin
    scene = Scene(resolution = (1000, 1000), font="SF Hello");
    screen = display(scene)
    campixel!(scene);

    la1 = LayoutedAxis(scene)
    la2 = LayoutedAxis(scene)
    la3 = LayoutedAxis(scene)
    la4 = LayoutedAxis(scene)
    la5 = LayoutedAxis(scene)

    linkxaxes!(la3, la4)
    linkyaxes!(la3, la5)

    fakeaudiox = LinRange(0f0, 1000f0, 100_000)
    fakeaudioy = (rand(Float32, 100_000) .- 0.5f0) .+ 2 .* sin.(fakeaudiox .* 10)

    lines!(la1.scene, fakeaudiox, fakeaudioy, show_axis=false)
    la1.attributes.title[] = "A fake audio signal"
    la1.limits[] = FRect(0f0, -3f0, 1000f0, 6f0)
    la1.attributes.ypanlock[] = true
    la1.attributes.yzoomlock[] = true

    linkeddata = randn(200, 2) .* 15 .+ 50
    green = RGBAf0(0.05, 0.8, 0.3, 0.6)
    scatter!(la3.scene, linkeddata, markersize=3, color=green, show_axis=false)

    kdepoly!(la4.scene, linkeddata[:, 1], 90, false, color=green, linewidth=2, show_axis=false)
    kdepoly!(la5.scene, linkeddata[:, 2], 90, true, color=green, linewidth=2, show_axis=false)
    update!(scene)

    # suptitle_pos = Node(Point2(0.0, 0.0))
    # suptitle = text!(scene, "Centered Super Title", position=suptitle_pos, textsize=50, font=boldface)[end]
    # suptitle_bbox = BBox(boundingbox(suptitle))
    #
    # midtitle_pos = Node(Point2(0.0, 0.0))
    # midtitle = text!(scene, "Left aligned subtitle", position=midtitle_pos, textsize=40, font=boldface)[end]
    # midtitle_bbox = BBox(boundingbox(midtitle))

    maingl = GridLayout(2, 1, parent=scene, alignmode=Outside(40))

    slalign = maingl[2, 1] = LayoutedSlider(scene, 30, LinRange(0.0, 60.0, 200))


    gl = maingl[1, 1] = GridLayout(
        2, 2;
        parent = scene,
        rowsizes = [Aspect(1, 1.0), Auto()],
        colsizes = [Relative(0.5), Auto()],
        addedrowgaps = Fixed(20),
        addedcolgaps = Fixed(20),
        alignmode = Outside(0))

    on(slalign.slider.value) do v
        with_updates_suspended(maingl) do
            gl.addedrowgaps = [Fixed(v)]
            gl.addedcolgaps = [Fixed(v)]
        end
    end

    gl_slider = gl[1, 2] = GridLayout(
        3, 1;
        rowsizes = [Auto(), Auto(), Auto()],
        colsizes = [Relative(1)],
        addedrowgaps = [Fixed(15), Fixed(15)])

    gl_colorbar = gl_slider[1, 1] = GridLayout(1, 2; colsizes=[Auto(), Relative(0.1)])

    gl_colorbar[1, 1] = la2
    gl_colorbar[1, 2] = LayoutedColorbar(scene)

    sl1 = gl_slider[2, 1] = LayoutedSlider(scene, 40, 1:0.01:10)
    sl2 = gl_slider[3, 1] = LayoutedSlider(scene, 40, 0.1:0.01:1)

    xrange = LinRange(0, 2pi, 500)
    lines!(
        la2.scene,
        xrange ./ 2pi .* 100,
        lift((x, y)->sin.(xrange .* x) .* 40 .* y .+ 50, sl1.slider.value, sl2.slider.value),
        color=:blue, linewidth=2, show_axis=false)

    gl[2, :] = la1

    gl2 = gl[1, 1] = GridLayout(
        2, 2,
        rowsizes = [Auto(), Relative(0.8)],
        colsizes = [Aspect(2, 1.0), Auto()],
        addedrowgaps = [Fixed(10)],
        addedcolgaps = [Fixed(10)])

    gl2[2, 1] = la3
    la3.attributes.titlevisible[] = false

    gl2[1, 1] = la4
    la4.attributes.xlabelvisible[] = false
    la4.attributes.xticklabelsvisible[] = false
    la4.attributes.xticksvisible[] = false
    la4.attributes.titlevisible[] = false
    la4.attributes.ypanlock[] = true
    la4.attributes.yzoomlock[] = true

    gl2[2, 2] = la5
    la5.attributes.ylabelvisible[] = false
    la5.attributes.yticklabelsvisible[] = false
    la5.attributes.yticksvisible[] = false
    la5.attributes.titlevisible[] = false
    la5.attributes.xpanlock[] = true
    la5.attributes.xzoomlock[] = true
end

la1.attributes.spinewidth[] = 1
la1.attributes.titlealign[] = :center
la1.attributes.title[] = "A fake audio signal"
la1.attributes.xticksize[] = 10

begin
    scene = Scene(resolution = (1000, 1000), font="SF Hello");
    screen = display(scene)
    campixel!(scene);

    maingl = GridLayout(
        1, 2;
        parent = scene,
        colsizes = [Auto(), Fixed(200)],
        addedcolgaps = Fixed(30),
        alignmode = Outside(30, 30, 30, 30)
    )

    gl = maingl[1, 1] = GridLayout(
        3, 3;
        rowsizes = Relative(1/3),
        colsizes = Auto(),
        addedcolgaps = Fixed(50),
        addedrowgaps = Fixed(20),
        alignmode = Outside()
    )

    las = []
    for i in 1:3, j in 1:3
        # la =
        # al = AxisLayout(gl, la.protrusions, la.bboxnode)
        la = gl[i, j] = LayoutedAxis(scene)
        scatter!(la.scene, rand(100, 2) .* 90 .+ 5, color=RGBf0(rand(3)...), raw=true, markersize=5)
        push!(las, la)
    end

    # buttons need change in abstractplotting to correctly update frame position

    glside = maingl[1, 2] = GridLayout(7, 1, alignmode=Outside())

    but = glside[1, 1] = LayoutedButton(scene, 200, 50, "Toggle Titles")
    on(but.button.clicks) do c
        for la in las
            la.attributes.titlevisible[] = !la.attributes.titlevisible[]
        end
    end

    but2 = glside[2, 1] = LayoutedButton(scene, 200, 50, "Toggle Labels")
    on(but2.button.clicks) do c
        for la in las
            la.attributes.xlabelvisible[] = !la.attributes.xlabelvisible[]
            la.attributes.ylabelvisible[] = !la.attributes.ylabelvisible[]
        end
    end

    but3 = glside[3, 1] = LayoutedButton(scene, 200, 50, "Toggle Ticklabels")
    on(but3.button.clicks) do c
        for la in las
            la.attributes.xticklabelsvisible[] = !la.attributes.xticklabelsvisible[]
            la.attributes.yticklabelsvisible[] = !la.attributes.yticklabelsvisible[]
        end
    end

    but4 = glside[4, 1] = LayoutedButton(scene, 200, 50, "Toggle Ticks")
    on(but4.button.clicks) do c
        t1 = time()
        with_updates_suspended(maingl) do
            for la in las
                la.attributes.xticksvisible[] = !la.attributes.xticksvisible[]
                la.attributes.yticksvisible[] = !la.attributes.yticksvisible[]
            end
        end
        println(time() - t1)
    end

    but5 = glside[5, 1] = LayoutedButton(scene, 200, 50, "Toggle Tick Align")
    on(but5.button.clicks) do c
        t1 = time()
        maingl.block_updates = true
        for la in las
            la.attributes.xtickalign[] = la.attributes.xtickalign[] == 1 ? 0 : 1
            la.attributes.ytickalign[] = la.attributes.ytickalign[] == 1 ? 0 : 1
        end
        maingl.block_updates = true
        maingl.needs_update[] = true
        println(time() - t1)
    end

    but6 = glside[6, 1] = LayoutedButton(scene, 200, 50, "Toggle Grids")
    on(but6.button.clicks) do c
        for la in las
            la.attributes.xgridvisible[] = !la.attributes.xgridvisible[]
            la.attributes.ygridvisible[] = !la.attributes.ygridvisible[]
        end
    end
end

las[1].attributes.rightspinevisible = true
las[1].attributes.spinewidth[] = 1
las[1].attributes.xidealtickdistance[] = 100
las[1].attributes.xticksize[] = 10
gl.needs_update[] = true
las[1].attributes.titlefont[] = boldface

begin
    begin
        for i in 1:9
            las[i].attributes.ylabelvisible[] = false
            las[i].attributes.xlabelvisible[] = false
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.yticklabelsvisible[] = false
            las[i].attributes.xticklabelsvisible[] = false
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.titlevisible[] = false
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.ylabelvisible[] = true
            las[i].attributes.xlabelvisible[] = true
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.yticklabelsvisible[] = true
            las[i].attributes.xticklabelsvisible[] = true
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.titlevisible[] = true
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.title[] = "Big\nTitle"
            las[i].attributes.ylabel[] = "Big\ny label"
            las[i].attributes.xlabel[] = "Big\nx label"
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.title[] = "Title"
            las[i].attributes.ylabel[] = "y label"
            las[i].attributes.xlabel[] = "x label"
            sleep(0.05)
        end
    end
    begin
        for i in 1:9
            las[i].attributes.ylabelsize[] = 30
            las[i].attributes.xlabelsize[] = 30
            las[i].attributes.yticklabelsize[] = 30
            las[i].attributes.xticklabelsize[] = 30
            sleep(0.05)
        end

        for i in 1:9
            las[i].attributes.ylabelsize[] = 20
            las[i].attributes.xlabelsize[] = 20
            las[i].attributes.yticklabelsize[] = 20
            las[i].attributes.xticklabelsize[] = 20
            sleep(0.05)
        end
    end
end
