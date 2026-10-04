using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

//! CONCEPT C — Blueprint Signal (layoutStyle=6). 448x486 technical blueprint:
//! header (datum | time | steps·HR) + mode tag, oscilloscope trace with
//! dashed thresholds and tagged TGT band, big glucose + trend arrow,
//! railway signal lights, monospace data table, status bar.
module CGMWatchfaceBlueprint {

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
        anzeigeTarget,
        anzeigeMode,
        anzeigeFehler,
        auswahlPfeil
    ) {
        AimicoDraw.hideClassicLabels(view);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var pad = 16;
        if (width < 400) { pad = 12; }

        var hyperProp = App.getApp().getProperty("hyperThreshold");
        var hyper = hyperProp != null ? hyperProp.toNumber() : 250;
        if (hyper == null) { hyper = 250; }

        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"].toNumber();
        }
        var state = BlueprintDrawing.stateFromSgv(sgvMgdl, zielbereichLow, hyper);
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
        if (anzeigeTarget != null && anzeigeTarget.equals("") == false) {
            targetNum = anzeigeTarget.toNumber();
        }
        // Layout (448x486, pad 16): header -> mode tag -> taller oscilloscope
        // (no time-axis strip) -> glucose + signal lights -> data table -> status.
        // Alert: predict hint between table and status bar.
        var tinyH = dc.getFontHeight(Gfx.FONT_XTINY);
        // Match drawGlucoseBlueprint font choice (MEDIUM, fallback MILD).
        var bgH = dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM);
        if (bgH > 88) {
            bgH = dc.getFontHeight(Gfx.FONT_NUMBER_MILD);
        }
        var headerY = pad;
        var tagY = headerY + tinyH + 6;
        var graphY = tagY + 24;
        var statusH = 20;
        var statusY = height - pad - statusH;
        var tableH = 72; // 3 rows x 24 (compact table)
        var alert = (state == BlueprintDrawing.STATE_HYPO || state == BlueprintDrawing.STATE_HYPER);
        var alertReserve = alert ? (tinyH + 10) : 0;
        // Budget remaining height for graph vs glucose block vs table
        var tableY = statusY - alertReserve - tableH - 6;
        // Arrow sits beside digits — no vertical reserve above SGV
        var gluBlockH = bgH + 10;
        var gluY = tableY - gluBlockH;
        var graphH = gluY - graphY - 8;
        if (graphH < 120) { graphH = 120; }
        if (graphH > 168) { graphH = 168; }
        // If graph was clamped, re-center glucose/table under it
        var afterGraph = graphY + graphH + 8;
        if (gluY < afterGraph) {
            gluY = afterGraph;
            tableY = gluY + gluBlockH;
            if (tableY + tableH + alertReserve > statusY - 4) {
                tableY = statusY - 4 - alertReserve - tableH;
                gluY = tableY - gluBlockH;
            }
        }
        var predictY = tableY + tableH + 6;

        BlueprintDrawing.drawBlueprintBackground(dc, state);
        BlueprintDrawing.drawHeader(dc, pad, datum, timeString, steps, heartrate);
        BlueprintDrawing.drawModeTag(dc, pad, tagY, anzeigeMode);

        BlueprintDrawing.drawOscilloscope(
            dc, pad, graphY, width - 2 * pad, graphH,
            past, future, targetNum, state
        );

        // Glucose block: digits + arrow; compact signal lights aligned to top of SGV
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }
        var gluCx = cx + 40;
        BlueprintDrawing.drawGlucoseBlueprint(dc, gluCx, gluY, sgvText, auswahlPfeil, state);
        BlueprintDrawing.drawSignalLights(dc, pad + 28, gluY + 2, state);

        BlueprintDrawing.drawDataTable(
            dc, pad, tableY, width - 2 * pad,
            tir, deltaNum, anzeigeIOB, ageMin, anzeigeBasal, targetNum
        );
        if (alert) {
            BlueprintDrawing.drawPredictHint(dc, cx, predictY, predict15, state);
        }
        BlueprintDrawing.drawStatusBar(dc, pad, statusY, width - 2 * pad, state, targetNum, anzeigeMode);

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, tableY - tinyH - 4, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
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
        if (state == BlueprintDrawing.STATE_HYPO && drift > -1) { drift = -3; }
        if (state == BlueprintDrawing.STATE_HYPER && drift < 1) { drift = 4; }
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
