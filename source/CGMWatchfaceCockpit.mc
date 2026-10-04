using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

//! CONCEPT C — Cockpit TIR (layoutStyle=7).
//! Top strip (date / time + mode chip / steps·HR), hero TIR ring with glucose inside,
//! compact graph band (target zone + 3h curve + dotted +60m prediction), 4 data tiles,
//! loop/state pill at the bottom.
module CGMWatchfaceCockpit {

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
        auswahlPfeil,
        anzeigeTarget,
        anzeigeMode
    ) {
        AimicoDraw.hideClassicLabels(view);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var pad = width >= 400 ? 16 : 12;
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
        var deltaNum = deltaFromAaps(punkte, anzeigeDelta);
        var future = mockFuture(past, sgvMgdl, deltaNum, state);
        var tir = tirFromAaps(punkte, past, zielbereichLow, zielbereichHigh);
        var ageMin = sanitizeAge(verzoegerung);
        var predict15 = null;
        if (future != null && future.size() >= 3) {
            predict15 = future[2]; // ~15 min at 5-min steps
        }
        var targetNum = null;
        if (anzeigeTarget != null) {
            targetNum = anzeigeTarget.toNumber();
        }

        // ---- layout (design target 448x486, 16px margins) ----
        var stripY = pad;
        var stripH = 36;
        var tileH = 54;
        var tileGap = 8;
        var tileY = height - pad - tileH;
        var pillH = 26;
        var pillGap = 8;
        var pillY = tileY - pillGap - pillH;
        var bandGap = 10;
        var bandH = 78;
        var bandY = pillY - bandGap - bandH;
        var bandX = pad;
        var bandW = width - 2 * pad;

        var ringTop = stripY + stripH + 6;
        var ringBottom = bandY - 8;
        var outerR = ((ringBottom - ringTop) / 2).toNumber() - 4;
        var maxR = ((width - 2 * pad) * 0.28).toNumber();
        if (outerR > maxR) { outerR = maxR; }
        if (outerR < 70) { outerR = 70; }
        var ringCy = ringTop + 4 + outerR;
        var tirLabelY = ringCy + outerR - 26;

        CockpitDrawing.drawVignetteBackground(dc, state);
        CockpitDrawing.drawTopStrip(dc, pad, datum, timeString, anzeigeMode, steps, heartrate);

        if (sgvMgdl != null) {
            CockpitDrawing.drawTirRing(dc, cx, ringCy, outerR, tir, state);
        }

        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }
        CockpitDrawing.drawGlucoseCockpit(dc, cx, ringCy, sgvText, auswahlPfeil, state);
        CockpitDrawing.drawTirLabel(dc, cx, tirLabelY, tir, state);

        CockpitDrawing.drawGraphBand(dc, bandX, bandY, bandW, bandH, past, future, targetNum, state);

        // ---- 4 data tiles: IOB / TBR / Δ / COB ----
        var tileW = (bandW - 3 * tileGap) / 4;
        var dStr = deltaNum > 0 ? "+" + deltaNum.toString() : deltaNum.toString();
        var iobVal = anzeigeIOB;
        if (iobVal == null || iobVal.equals("")) { iobVal = "-- U"; }
        var tbrVal = anzeigeBasal;
        if (tbrVal == null || tbrVal.equals("") || tbrVal.equals("-- %") || tbrVal.equals("--")) { tbrVal = "--"; }
        var cobVal = anzeigeCOB;
        if (cobVal == null || cobVal.equals("")) { cobVal = "-- g"; }
        CockpitDrawing.drawTile(dc, bandX, tileY, tileW, tileH, "IOB", iobVal, 0x33DDFF);
        CockpitDrawing.drawTile(dc, bandX + (tileW + tileGap), tileY, tileW, tileH, "TBR", tbrVal, 0xFFB020);
        CockpitDrawing.drawTile(dc, bandX + 2 * (tileW + tileGap), tileY, tileW, tileH, "Δ", dStr, 0x00E065);
        CockpitDrawing.drawTile(dc, bandX + 3 * (tileW + tileGap), tileY, tileW, tileH, "COB", cobVal, 0xAAAAAA);

        CockpitDrawing.drawStatePill(dc, cx, pillY, state, null);

        // alert hint / error line between ring and graph band
        var err = AimicoDraw.friendlyError(anzeigeFehler);
        var msgY = bandY - 16;
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, msgY, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        } else if (state == CockpitDrawing.STATE_HYPO || state == CockpitDrawing.STATE_HYPER) {
            CockpitDrawing.drawPredictHint(dc, cx, msgY, predict15, state);
        }
    }

    function stateFromSgv(sgv, low, hyper) {
        if (sgv == null) { return CockpitDrawing.STATE_NORMAL; }
        var v = sgv.toNumber();
        if (v == null || v < 20 || v > 600) { return CockpitDrawing.STATE_NORMAL; }
        var lo = low != null ? low.toNumber() : 70;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return CockpitDrawing.STATE_HYPO; }
        if (v >= hy) { return CockpitDrawing.STATE_HYPER; }
        return CockpitDrawing.STATE_NORMAL;
    }

    //! Prefer raw AAPS `delta` (number); fall back to display string (strip leading '+').
    function deltaFromAaps(punkte, anzeigeDelta) {
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["delta"] != null) {
            var raw = punkte[0]["delta"].toNumber();
            if (raw != null) { return raw; }
        }
        return parseDelta(anzeigeDelta);
    }

    //! Prefer AAPS `tir` on latest point; fall back to local calc over graph.
    function tirFromAaps(punkte, past, low, high) {
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["tir"] != null) {
            var t = punkte[0]["tir"].toNumber();
            if (t != null) {
                if (t < 0) { t = 0; }
                if (t > 100) { t = 100; }
                return t;
            }
        }
        return calcTir(past, low, high);
    }

    function parseDelta(anzeigeDelta) {
        if (anzeigeDelta == null || anzeigeDelta.equals("") || anzeigeDelta.equals("--")) { return 0; }
        var s = anzeigeDelta.toString();
        // "+3" breaks String.toNumber() on some CIQ runtimes
        if (s.length() > 0) {
            var c0 = s.substring(0, 1);
            if (c0.equals("+")) {
                s = s.substring(1, s.length());
            }
        }
        var n = s.toNumber();
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
        if (state == CockpitDrawing.STATE_HYPO && drift > -1) { drift = -3; }
        if (state == CockpitDrawing.STATE_HYPER && drift < 1) { drift = 4; }
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
