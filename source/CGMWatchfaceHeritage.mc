using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

//! CONCEPT C — Heritage (layoutStyle=6). Central unicorn carries glycaemia state.
module CGMWatchfaceHeritage {

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
        var pad = isRound ? ((width * 0.08).toNumber()) : (width >= 400 ? 16 : 12);
        if (pad < 12) { pad = 12; }

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

        // Scale 448 reference → device
        var scale = height.toFloat() / 448.0;
        var timeH = dc.getFontHeight(Gfx.FONT_XTINY);
        var topBarH = timeH + 4;
        var gluY = pad + topBarH;
        var gluFontH = dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM);
        if (gluFontH > 52) {
            gluFontH = dc.getFontHeight(Gfx.FONT_NUMBER_MILD);
        }
        // Glucose + arrow must sit fully above the ring
        var arrowBlock = 26; // mid + tip below SGV
        var gapAboveRing = 10;
        var sgvBlockBottom = gluY + gluFontH + arrowBlock;
        var ringTopMin = sgvBlockBottom + gapAboveRing;

        var sparkH = (32.0 * scale).toNumber();
        if (sparkH < 20) { sparkH = 20; }
        if (sparkH > 36) { sparkH = 36; }
        var metricsH = timeH + 6;
        var footerH = timeH + pad + 4;
        var sparkY = height - footerH - sparkH - 6;
        var ringBotMax = sparkY - metricsH - 6;

        // Fit halo in remaining band; never let ring climb into SGV
        var band = ringBotMax - ringTopMin;
        if (band < 120) { band = 120; }
        var haloR = (band * 0.48).toNumber();
        var maxHalo = ((width < height ? width : height) * 0.28).toNumber();
        if (haloR > maxHalo) { haloR = maxHalo; }
        if (haloR < 70) { haloR = 70; }
        if (2 * haloR > band) {
            haloR = (band / 2).toNumber() - 2;
            if (haloR < 64) { haloR = 64; }
        }
        // Anchor: top of ring exactly at ringTopMin
        var uniCy = ringTopMin + haloR;
        if (uniCy + haloR > ringBotMax) {
            uniCy = ringBotMax - haloR;
            // If still overlapping SGV, shrink halo again
            if (uniCy - haloR < ringTopMin) {
                haloR = ((ringBotMax - ringTopMin) / 2).toNumber() - 2;
                uniCy = ringTopMin + haloR;
            }
        }

        var uniSize = (haloR * 1.55).toNumber();
        if (uniSize > 200) { uniSize = 200; }
        if (uniSize < 110) { uniSize = 110; }

        HeritageDrawing.drawVignetteBackground(dc, state);

        var headInset = HeritageDrawing.edgeInsetX(pad + 4, width, height, isRound);
        HeritageDrawing.drawTopBar(dc, headInset, datum, steps, heartrate);

        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }
        HeritageDrawing.drawGlucoseSmallTop(dc, cx, gluY, sgvText, auswahlPfeil, state);

        if (sgvMgdl != null) {
            HeritageDrawing.drawHaloRing(dc, cx, uniCy, haloR, tir, state);
        }
        HeritageDrawing.drawUnicornByState(dc, cx, uniCy, uniSize, sgvMgdl, auswahlPfeil);
        HeritageDrawing.drawSideMetrics(dc, cx, uniCy, haloR, anzeigeIOB, anzeigeBasal, state);

        if (graph != null && graph.size() >= 2) {
            var sparkInset = HeritageDrawing.edgeInsetX(sparkY + sparkH / 2, width, height, isRound);
            HeritageDrawing.drawSmileSparkline(dc, sparkInset, sparkY, width - sparkInset * 2, sparkH, graph, state);
        }

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, sparkY - 14, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, height - pad - timeH, Gfx.FONT_XTINY, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function stateFromSgv(sgv, low, hyper) {
        if (sgv == null) { return HeritageDrawing.STATE_NORMAL; }
        var v = sgv.toNumber();
        if (v == null || v < 20 || v > 600) { return HeritageDrawing.STATE_NORMAL; }
        var lo = low != null ? low.toNumber() : 70;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return HeritageDrawing.STATE_HYPO; }
        if (v >= hy) { return HeritageDrawing.STATE_HYPER; }
        return HeritageDrawing.STATE_NORMAL;
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
