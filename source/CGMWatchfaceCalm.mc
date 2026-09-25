using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

//! CONCEPT A — Calm Loop (layoutStyle=4). Minimal chrome; alert via vignette + pill.
module CGMWatchfaceCalm {

    function draw(
        view,
        dc,
        isHighPower,
        steps,
        heartrate,
        timeString,
        datum,
        punkte,
        zielbereichLow,
        zielbereichHigh,
        anzeigeSGV,
        anzeigeDelta,
        verzoegerung,
        anzeigeIOB,
        anzeigeBasal,
        anzeigeCOB,
        anzeigeFehler,
        auswahlPfeil
    ) {
        AimicoDraw.hideClassicLabels(view);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var settings = Sys.getDeviceSettings();
        var isRound = false;
        if (settings has :screenShape) {
            isRound = settings.screenShape == Sys.SCREEN_SHAPE_ROUND;
        }

        var pad = width >= 400 ? 16 : 12;
        if (isRound) { pad = (width * 0.08).toNumber(); }
        if (pad < 14) { pad = 14; }

        var hyperProp = App.getApp().getProperty("hyperThreshold");
        var hyper = hyperProp != null ? hyperProp.toNumber() : 250;
        if (hyper == null) { hyper = 250; }

        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"].toNumber();
        }
        var state = stateFromSgv(sgvMgdl, zielbereichLow, hyper);
        var graph = buildGraph(punkte);
        var tir = calcTir(graph, zielbereichLow, zielbereichHigh);

        // Scale 448 reference → device (slightly smaller ring on round)
        var scale = height.toFloat() / 448.0;
        var topPad = isRound ? pad + 4 : pad;
        var ringFrac = isRound ? 0.26 : (132.0 / 448.0);
        var gluCy = isRound ? ((height * 0.40).toNumber()) : (190.0 * scale).toNumber();
        var ringR = ((width < height ? width : height).toFloat() * ringFrac).toNumber();
        if (ringR < 68) { ringR = 68; }
        if (isRound && ringR > width * 0.36) { ringR = (width * 0.36).toNumber(); }

        var sparkH = (22.0 * scale).toNumber();
        if (sparkH < 14) { sparkH = 14; }
        if (sparkH > 24) { sparkH = 24; }

        var timeH = dc.getFontHeight(Gfx.FONT_SMALL);
        var bottomPad = isRound ? pad + 10 : pad;
        var timeY = height - bottomPad - timeH;
        var pillReserve = 0;
        if (state == CalmDrawing.STATE_HYPO || state == CalmDrawing.STATE_HYPER) {
            pillReserve = 32;
            timeY = height - bottomPad - pillReserve - timeH;
        }
        var sparkY = gluCy + ringR + (isRound ? 10 : 12);
        var maxSparkBottom = timeY - 18;
        if (sparkY + sparkH > maxSparkBottom) {
            sparkY = maxSparkBottom - sparkH;
        }

        CalmDrawing.drawVignetteBackground(dc, state);

        var headInset = CalmDrawing.edgeInsetX(topPad + 4, width, height, isRound);
        CalmDrawing.drawTopBarMinimal(dc, headInset, datum, steps, heartrate, state);

        var showTirProp = App.getApp().getProperty("showTirRing");
        var showTir = showTirProp == null || showTirProp.toNumber() != 0;
        if (showTir && sgvMgdl != null) {
            CalmDrawing.drawThinTirRing(dc, cx, gluCy, ringR, tir, state);
        }

        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }
        CalmDrawing.drawGlucoseCalm(dc, cx, gluCy, sgvText, auswahlPfeil, anzeigeDelta, state);
        CalmDrawing.drawRingLoopMetrics(dc, cx, gluCy, ringR, anzeigeIOB, anzeigeBasal, state);

        if (graph != null && graph.size() >= 2 && sparkH >= 12) {
            var sparkInset = CalmDrawing.edgeInsetX(sparkY + sparkH / 2, width, height, isRound);
            CalmDrawing.drawCalmSparkline(dc, sparkInset, sparkY, width - sparkInset * 2, sparkH, graph, state);
        }

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, sparkY - 14, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }

        CalmDrawing.drawBottomPill(dc, state, "3.4");

        dc.setColor(0xAAAAAA, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, timeY, Gfx.FONT_SMALL, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Calm states: HIGH (180–249) stays visually NORMAL.
    function stateFromSgv(sgv, low, hyper) {
        if (sgv == null) { return CalmDrawing.STATE_NORMAL; }
        var v = sgv.toNumber();
        if (v == null || v < 20 || v > 600) { return CalmDrawing.STATE_NORMAL; }
        var lo = low != null ? low.toNumber() : 70;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return CalmDrawing.STATE_HYPO; }
        if (v >= hy) { return CalmDrawing.STATE_HYPER; }
        return CalmDrawing.STATE_NORMAL;
    }

    function buildGraph(punkte) {
        var out = [];
        if (bgReadingsAccumulated != null && bgReadingsAccumulated instanceof Lang.Array) {
            var n = bgReadingsAccumulated.size();
            var start = 0;
            if (n > 36) { start = n - 36; }
            for (var i = n - 1; i >= start; i--) {
                if (bgReadingsAccumulated[i] != null && bgReadingsAccumulated[i]["sgv"] != null) {
                    var v = bgReadingsAccumulated[i]["sgv"].toNumber();
                    if (v != null && v >= 20 && v <= 600) {
                        out.add(v);
                    }
                }
            }
        }
        if (out.size() < 2 && punkte != null && punkte instanceof Lang.Array) {
            out = [];
            for (var j = punkte.size() - 1; j >= 0; j--) {
                if (punkte[j] != null && punkte[j]["sgv"] != null) {
                    var v2 = punkte[j]["sgv"].toNumber();
                    if (v2 != null && v2 >= 20 && v2 <= 600) {
                        out.add(v2);
                    }
                }
            }
        }
        return out;
    }

    function calcTir(graph, low, high) {
        if (graph == null || graph.size() == 0) { return 0; }
        var lo = low != null ? low.toNumber() : 70;
        var hi = high != null ? high.toNumber() : 180;
        if (lo == null) { lo = 70; }
        if (hi == null) { hi = 180; }
        var inRange = 0;
        for (var i = 0; i < graph.size(); i++) {
            if (graph[i] >= lo && graph[i] <= hi) { inRange++; }
        }
        return ((inRange * 100) / graph.size()).toNumber();
    }

}
