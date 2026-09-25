using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

//! CONCEPT B — Pilot (layoutStyle=5). Target band + past/future sparkline + double ring.
module CGMWatchfacePilot {

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
        var past = buildGraph(punkte);
        var deltaNum = parseDelta(anzeigeDelta);
        var future = mockFuture(past, sgvMgdl, deltaNum, state);
        var tir = calcTir(past, zielbereichLow, zielbereichHigh);
        var ageMin = sanitizeAge(verzoegerung);
        var predict15 = null;
        if (future != null && future.size() >= 3) {
            predict15 = future[2]; // ~15 min at 5-min steps
        }

        // Layout: band above ring (no overlap), no LOOP pill — free bottom for tech/TIR/time
        var headInset = PilotDrawing.edgeInsetX(pad + 4, width, height, isRound);
        var topBarH = dc.getFontHeight(Gfx.FONT_XTINY) + 6;
        var timeH = dc.getFontHeight(Gfx.FONT_XTINY);
        var footerH = timeH + (isRound ? 10 : 6);
        var bandH = (isRound ? 48 : 54);
        var bandY = pad + topBarH + 2;
        var bandBottom = bandY + bandH;

        var availBottom = height - pad - footerH;
        var availForRing = availBottom - bandBottom - 40; // room for tech + TIR below ring
        var outerR = (availForRing * 0.48).toNumber();
        var maxR = ((width < height ? width : height) * (isRound ? 0.30 : 0.28)).toNumber();
        if (outerR > maxR) { outerR = maxR; }
        if (outerR < 88) { outerR = 88; }
        var innerR = outerR - 16;
        // Small clear gap under graph (~8px), not touching
        var gluCy = bandBottom + 8 + outerR;
        var ringBottom = gluCy + outerR;
        if (ringBottom > availBottom - 44) {
            gluCy = availBottom - 44 - outerR;
        }

        var bandInset = PilotDrawing.edgeInsetX(bandY + bandH / 2, width, height, isRound);

        PilotDrawing.drawVignetteBackground(dc, state);
        PilotDrawing.drawTopBar(dc, headInset, datum, steps, heartrate);

        PilotDrawing.drawTargetBand(dc, bandInset, bandY, width - bandInset * 2, bandH);
        PilotDrawing.drawPredictiveSparkline(
            dc, bandInset + 2, bandY + 2, width - bandInset * 2 - 4, bandH - 14,
            past, future, state
        );

        if (sgvMgdl != null) {
            PilotDrawing.drawDoubleRing(dc, cx, gluCy, outerR, innerR, tir, deltaNum, state);
        }

        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }
        PilotDrawing.drawGlucosePilot(dc, cx, gluCy, sgvText, auswahlPfeil, anzeigeDelta, state);

        // Tech + TIR below the ring with clear air gap
        var techY = gluCy + outerR + 10;
        if (techY > availBottom - (timeH * 2) - 4) {
            techY = availBottom - (timeH * 2) - 4;
        }
        PilotDrawing.drawTechLine(dc, cx, techY, anzeigeIOB, anzeigeBasal, anzeigeCOB, ageMin);
        var tirY = techY + timeH + 4;
        PilotDrawing.drawRingLabels(dc, cx, tirY, outerR, tir, deltaNum);

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, techY - 14, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }

        // Alert-only predict hint above time (no LOOP pill)
        if (state == PilotDrawing.STATE_HYPO || state == PilotDrawing.STATE_HYPER) {
            PilotDrawing.drawPredictHint(dc, cx, height - pad - timeH - timeH - 2, predict15, state);
        }

        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, height - pad - timeH, Gfx.FONT_XTINY, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function stateFromSgv(sgv, low, hyper) {
        if (sgv == null) { return PilotDrawing.STATE_NORMAL; }
        var v = sgv.toNumber();
        if (v == null || v < 20 || v > 600) { return PilotDrawing.STATE_NORMAL; }
        var lo = low != null ? low.toNumber() : 70;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return PilotDrawing.STATE_HYPO; }
        if (v >= hy) { return PilotDrawing.STATE_HYPER; }
        return PilotDrawing.STATE_NORMAL;
    }

    function parseDelta(anzeigeDelta) {
        if (anzeigeDelta == null || anzeigeDelta.equals("") || anzeigeDelta.equals("--")) { return 0; }
        var n = anzeigeDelta.toNumber();
        if (n == null) { return 0; }
        return n;
    }

    function sanitizeAge(verzoegerung) {
        if (verzoegerung == null) { return null; }
        if (verzoegerung instanceof Lang.String) {
            if (verzoegerung.equals("--") || verzoegerung.equals("999")) { return null; }
            var n = verzoegerung.toNumber();
            if (n == null || n < 0 || n > 999) { return null; }
            return n;
        }
        var v = verzoegerung.toNumber();
        if (v == null || v < 0 || v > 999) { return null; }
        return v;
    }

    //! Mock +60m prediction until AAPS sends graphFuture (HTTP plan A).
    function mockFuture(past, sgv, delta, state) {
        var out = [];
        var base = sgv != null ? sgv : 120;
        if (past != null && past.size() > 0) {
            base = past[past.size() - 1];
        }
        var step = delta;
        if (step == null) { step = 0; }
        // Soften delta over 5-min steps
        var drift = step;
        if (state == PilotDrawing.STATE_HYPO && drift > -1) { drift = -3; }
        if (state == PilotDrawing.STATE_HYPER && drift < 1) { drift = 4; }
        for (var i = 1; i <= 12; i++) {
            var v = base + ((drift * i) / 2);
            if (v < 40) { v = 40; }
            if (v > 400) { v = 400; }
            out.add(v.toNumber());
        }
        return out;
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
