using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;

//! CONCEPT — Atelier (layoutStyle=8).
//! Horological dial on 448x486: filigrane graph behind analog hands,
//! TIR arc, date window + mode chip, glucose complication, sub-dials.
//! Alert states reuse the Pilot visual language.
module CGMWatchfaceAtelier {

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
        anzeigeMode,
        anzeigeTbrMins
    ) {
        AimicoDraw.hideClassicLabels(view);
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var pad = 16;

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
        var predict15 = null;
        if (future != null && future.size() >= 3) {
            predict15 = future[2]; // ~15 min at 5-min steps
        }
        var alert = (state == PilotDrawing.STATE_HYPO || state == PilotDrawing.STATE_HYPER);

        // Layout (448x486 reference, pad 16)
        var dialCx = cx;
        var dialCy = 246;
        var dialR = 172;

        // 1. Background + alert vignette (pilot language)
        dc.setColor(0x000000, 0x000000);
        dc.fillRectangle(0, 0, width, height);
        PilotDrawing.drawVignetteBackground(dc, state);

        // 2. Filigrane graph — drawn first, behind everything else
        AtelierDrawing.drawFiligraneGraph(dc, dialCx - 168, dialCy - 106, 336, 212, past, future);

        // 3. Dial rings (guilloche hint)
        AtelierDrawing.drawDialRings(dc, dialCx, dialCy, dialR);

        // 4. Steps (top-left) / HR (top-right)
        AtelierDrawing.drawTopMetrics(dc, pad, width, steps, heartrate);

        // 5. TIR arc over the dial top
        AtelierDrawing.drawTirArc(dc, dialCx, dialCy, dialR + 16, tir, state);

        // 6. Analog hands + trend arrow above the hub
        AtelierDrawing.drawHands(dc, dialCx, dialCy);
        AtelierDrawing.drawTrendAboveHands(dc, dialCx, dialCy, auswahlPfeil);

        // 7. Date window + mode chip at 3 o'clock
        AtelierDrawing.drawDateWindow(dc, dialCx + 66, dialCy - 17, 88, 34, datum, anzeigeMode);

        // 8. Glucose complication at 6 o'clock (no side arrow)
        var sgvText = "--";
        if (anzeigeSGV != null && !anzeigeSGV.equals("") && !anzeigeSGV.equals("--")) {
            sgvText = anzeigeSGV;
        }
        AtelierDrawing.drawGlucoseAtelier(dc, dialCx, 348, sgvText, state);

        // 9. Sub-dials first (IOB left / Δ right) so TBR is sized to the gap between them
        var iobVal = "--";
        if (anzeigeIOB != null && !anzeigeIOB.equals("")) {
            iobVal = anzeigeIOB;
            // Drop trailing " U" so the value fits under the icon
            if (iobVal.length() >= 2) {
                var tail = iobVal.substring(iobVal.length() - 2, iobVal.length());
                if (tail.equals(" U")) {
                    iobVal = iobVal.substring(0, iobVal.length() - 2);
                }
            }
        }
        var dStr = "--";
        if (deltaNum != null) {
            dStr = deltaNum > 0 ? ("+" + deltaNum.toString()) : deltaNum.toString();
        }
        var subR = 38;
        var subY = 400;
        var iobCx = 72;
        var dltCx = width - 72;
        AtelierDrawing.drawIobSubDial(dc, iobCx, subY, subR, iobVal);
        AtelierDrawing.drawSubDial(dc, dltCx, subY, subR, dStr);

        // 10. TBR centered in the clear gap between sub-dials (never overlaps circles)
        var gapL = iobCx + subR + 10;
        var gapR = dltCx - subR - 10;
        var tbrMaxW = gapR - gapL;
        AtelierDrawing.drawTherapyLine(dc, dialCx, subY - 4, tbrMaxW, anzeigeBasal, anzeigeTbrMins, null);

        // 11. Alert extras (pilot language)
        if (alert) {
            PilotDrawing.drawPredictHint(dc, dialCx, 414, predict15, state);
        }

        // 12. Bottom: targetBg (replaces LOOP · AAPS)
        var tgtY = height - pad - 26;
        AtelierDrawing.drawTargetBottom(dc, dialCx, tgtY, anzeigeTarget);

        // 13. Error line (only when not alert — alert visuals take priority)
        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (!err.equals("") && !alert) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(dialCx, 414, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
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
