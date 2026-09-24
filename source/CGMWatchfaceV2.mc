using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as Sys;

//! V2 color-aware layout (layoutStyle=3) — HTTP AAPS data, TIR ring, sparkline, state banners.
module CGMWatchfaceV2 {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;
    const STATE_HYPER = 3;

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
        var pad = width >= 360 ? 14 : 10;

        var hyperProp = App.getApp().getProperty("hyperThreshold");
        var hyper = hyperProp != null ? hyperProp.toNumber() : 250;
        if (hyper == null) { hyper = 250; }

        var showTirProp = App.getApp().getProperty("showTirRing");
        var showTir = showTirProp == null || showTirProp.toNumber() != 0;

        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"].toNumber();
        }
        var state = stateFromSgv(sgvMgdl, zielbereichLow, zielbereichHigh, hyper);
        var graph = buildGraph(punkte);
        var tir = calcTir(graph, zielbereichLow, zielbereichHigh);

        drawBackground(dc, width, height, state);

        // Header
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, pad - 2, Gfx.FONT_TINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(width - pad, pad - 2, Gfx.FONT_TINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);
        if (state != STATE_NORMAL) {
            dc.setColor(0xFFCC00, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, pad - 2, Gfx.FONT_TINY, "!", Gfx.TEXT_JUSTIFY_CENTER);
        }

        var headerH = dc.getFontHeight(Gfx.FONT_TINY) + 10;
        var bannerH = 34;
        var timeFont = Gfx.FONT_NUMBER_MEDIUM;
        var timeH = dc.getFontHeight(timeFont);
        var techH = dc.getFontHeight(Gfx.FONT_TINY) + 4;
        var sparkH = (height * 0.16).toNumber();
        if (sparkH < 48) { sparkH = 48; }
        if (sparkH > 80) { sparkH = 80; }

        var bannerY = height - pad - bannerH;
        var timeY = bannerY - 6 - timeH;
        var techY = timeY - techH - 2;
        var sparkY = techY - sparkH - 6;
        var gluCy = headerH + ((sparkY - headerH) * 0.42).toNumber();
        var cx = width / 2;
        var ringR = ((width < height ? width : height) * 0.28).toNumber();

        if (showTir) {
            drawTirRing(dc, cx, gluCy, ringR, tir, state);
        }

        // Unicorn small (optional)
        if (AimicoDraw.shouldShowMascot(isHighPower)) {
            var kind = AimicoState.mascotKind(sgvMgdl, zielbereichLow, zielbereichHigh);
            if (kind.equals("none")) { kind = "inrange"; }
            var bmp = AimicoState.mascotDrawable(kind);
            if (bmp != null) {
                var mw = 42;
                var mh = 56;
                AimicoDraw.drawMascotScaled(dc, bmp, pad, gluCy - mh / 2 - 10, mw, mh);
            }
        }

        // Glucose
        var gluCol = 0x2C8EFF;
        if (state != STATE_NORMAL) { gluCol = 0xFFFFFF; }
        dc.setColor(gluCol, Gfx.COLOR_TRANSPARENT);
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false) {
            sgvText = anzeigeSGV;
        }
        var fontBg = Gfx.FONT_NUMBER_HOT;
        dc.drawText(cx, gluCy - dc.getFontHeight(fontBg) / 2 - 8, fontBg, sgvText, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xAAAAAA, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, gluCy + dc.getFontHeight(fontBg) / 2 - 6, Gfx.FONT_TINY, "mg/dL", Gfx.TEXT_JUSTIFY_CENTER);

        // Delta + arrow under glucose
        var rowY = gluCy + dc.getFontHeight(fontBg) / 2 + 10;
        AimicoDraw.drawDeltaRow(dc, cx + 70, rowY, verzoegerung, anzeigeDelta, auswahlPfeil);

        // Sparkline
        drawSparkline(dc, pad, sparkY, width - pad * 2, sparkH, graph, state);
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, sparkY + sparkH + 1, Gfx.FONT_XTINY, "3h", Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(width - pad, sparkY + sparkH + 1, Gfx.FONT_XTINY, "now", Gfx.TEXT_JUSTIFY_RIGHT);

        // Tech + TIR label
        var tech = "";
        if (anzeigeIOB != null && anzeigeIOB.equals("") == false) { tech = anzeigeIOB; }
        if (anzeigeBasal != null && anzeigeBasal.equals("") == false) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + anzeigeBasal;
        }
        if (anzeigeCOB != null && anzeigeCOB.equals("") == false) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + anzeigeCOB;
        }
        if (state == STATE_HYPO) {
            tech = "LOW · TIR " + tir.toString() + "%";
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
        } else if (state == STATE_HYPER || state == STATE_HIGH) {
            tech = "HIGH · TIR " + tir.toString() + "%";
            dc.setColor(0xFF8C00, Gfx.COLOR_TRANSPARENT);
        } else {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + tir.toString() + "% TIR";
            dc.setColor(0xCCCCCC, Gfx.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, techY, Gfx.FONT_TINY, tech, Gfx.TEXT_JUSTIFY_CENTER);

        // Time
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, timeY, timeFont, timeString, Gfx.TEXT_JUSTIFY_CENTER);

        // Error overlay
        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, timeY - techH, Gfx.FONT_TINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }

        // Banner
        var bgC = 0x111111;
        var bTxt = "LOOP · AAPS";
        if (state == STATE_HYPO) {
            bgC = 0xFF1A1A;
            bTxt = "HYPO · AAPS";
        } else if (state == STATE_HYPER) {
            bgC = 0xFF6A00;
            bTxt = "HIGH · AAPS";
        } else if (state == STATE_HIGH) {
            bgC = 0xCC5500;
            bTxt = "HIGH · AAPS";
        }
        dc.setColor(bgC, bgC);
        dc.fillRoundedRectangle(pad, bannerY, width - pad * 2, bannerH, 12);
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, bannerY + bannerH / 2, Gfx.FONT_SMALL, bTxt, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function stateFromSgv(sgv, low, high, hyper) {
        if (sgv == null) { return STATE_NORMAL; }
        var v = sgv.toNumber();
        var lo = low != null ? low.toNumber() : 70;
        var hi = high != null ? high.toNumber() : 180;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hi == null) { hi = 180; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return STATE_HYPO; }
        if (v >= hy) { return STATE_HYPER; }
        if (v > hi) { return STATE_HIGH; }
        return STATE_NORMAL;
    }

    function buildGraph(punkte) {
        var out = [];
        // Prefer accumulated history if present
        if (bgReadingsAccumulated != null && bgReadingsAccumulated instanceof Lang.Array) {
            var n = bgReadingsAccumulated.size();
            var start = 0;
            if (n > 36) { start = n - 36; }
            for (var i = n - 1; i >= start; i--) {
                if (bgReadingsAccumulated[i] != null && bgReadingsAccumulated[i]["sgv"] != null) {
                    var v = bgReadingsAccumulated[i]["sgv"].toNumber();
                    if (v != null && v > 0) {
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
                    if (v2 != null && v2 > 0) {
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
            var v = graph[i];
            if (v >= lo && v <= hi) { inRange++; }
        }
        return ((inRange * 100) / graph.size()).toNumber();
    }

    function drawBackground(dc, w, h, state) {
        var top = 0x000000;
        var bottom = 0x000000;
        if (state == STATE_HYPO) {
            top = 0x4A0000;
            bottom = 0x1A0000;
        } else if (state == STATE_HYPER || state == STATE_HIGH) {
            top = 0x5A2500;
            bottom = 0x1F0F00;
        }
        if (top == bottom) {
            dc.setColor(top, top);
            dc.fillRectangle(0, 0, w, h);
            return;
        }
        // Sampled gradient (every 2px) for perf
        for (var y = 0; y < h; y += 2) {
            var r = y.toFloat() / h.toFloat();
            var tr = (top >> 16) & 0xFF;
            var tg = (top >> 8) & 0xFF;
            var tb = top & 0xFF;
            var br = (bottom >> 16) & 0xFF;
            var bg = (bottom >> 8) & 0xFF;
            var bb = bottom & 0xFF;
            var cr = (tr * (1 - r) + br * r).toNumber();
            var cg = (tg * (1 - r) + bg * r).toNumber();
            var cb = (tb * (1 - r) + bb * r).toNumber();
            var col = (cr << 16) | (cg << 8) | cb;
            dc.setColor(col, col);
            dc.drawLine(0, y, w, y);
            if (y + 1 < h) {
                dc.drawLine(0, y + 1, w, y + 1);
            }
        }
    }

    function drawTirRing(dc, cx, cy, radius, tir, state) {
        var startA = 135;
        var sweep = 270;
        var tirA = ((tir.toFloat() / 100.0) * sweep).toNumber();
        var col = 0x00E676;
        if (state == STATE_HYPO) { col = 0xFF3D57; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { col = 0xFF8C00; }

        dc.setPenWidth(8);
        dc.setColor(0x222222, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, startA, startA + sweep);
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        if (tirA > 0) {
            dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, startA, startA + tirA);
        }
        if (state == STATE_HYPO) {
            dc.setPenWidth(2);
            for (var a = startA; a < startA + sweep; a += 8) {
                var rad = Math.toRadians(a);
                var x1 = cx + radius * Math.cos(rad);
                var y1 = cy + radius * Math.sin(rad);
                var x2 = cx + (radius - 6) * Math.cos(rad);
                var y2 = cy + (radius - 6) * Math.sin(rad);
                dc.drawLine(x1, y1, x2, y2);
            }
        }
    }

    function drawSparkline(dc, x, y, w, h, graph, state) {
        if (graph == null || graph.size() < 2) { return; }
        var gMin = 500;
        var gMax = 0;
        for (var i = 0; i < graph.size(); i++) {
            if (graph[i] < gMin) { gMin = graph[i]; }
            if (graph[i] > gMax) { gMax = graph[i]; }
        }
        if (gMax - gMin < 40) {
            var mid = (gMax + gMin) / 2;
            gMin = mid - 20;
            gMax = mid + 20;
        }
        var lineC = 0x2C8EFF;
        var fillC = 0x112233;
        if (state == STATE_HYPO) {
            lineC = 0xFFFFFF;
            fillC = 0x330000;
        } else if (state == STATE_HYPER || state == STATE_HIGH) {
            lineC = 0xFFFFFF;
            fillC = 0x331A00;
        }

        var pts = [];
        for (var i = 0; i < graph.size(); i++) {
            var px = x + ((i.toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var norm = (graph[i] - gMin).toFloat() / (gMax - gMin).toFloat();
            var py = y + h - (norm * h).toNumber();
            pts.add([px, py]);
        }
        dc.setColor(fillC, Gfx.COLOR_TRANSPARENT);
        for (var i = 0; i < pts.size() - 1; i++) {
            dc.fillPolygon([
                [pts[i][0], pts[i][1]],
                [pts[i + 1][0], pts[i + 1][1]],
                [pts[i + 1][0], y + h],
                [pts[i][0], y + h]
            ]);
        }
        dc.setColor(lineC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < pts.size() - 1; i++) {
            dc.drawLine(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]);
        }
    }

}
