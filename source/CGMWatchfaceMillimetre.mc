using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.System as Sys;
using Toybox.Time as Time;

//! CONCEPT — Millimétré (layoutStyle=9). Paper millimetric lab recorder.
module CGMWatchfaceMillimetre {

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
        var state = MillimetreDrawing.stateFromSgv(sgvMgdl, zielbereichLow, hyper);
        var built = buildGraphWithTs(punkte);
        var past = built[0];
        var pastTs = built[1];
        var deltaNum = deltaFromAaps(punkte, anzeigeDelta);
        var future = mockFuture(past, sgvMgdl, deltaNum, state);
        var tir = tirFromAaps(punkte, past, zielbereichLow, zielbereichHigh);
        var predict15 = null;
        if (future != null && future.size() >= 3) {
            predict15 = future[2];
        }
        var targetNum = null;
        if (anzeigeTarget != null && anzeigeTarget.equals("") == false) {
            targetNum = anzeigeTarget.toNumber();
        }
        var basalSteps = null;
        var smbTs = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0) {
            basalSteps = punkte[0]["basalHistory"];
            smbTs = punkte[0]["smbHistory"];
        }

        var tinyH = dc.getFontHeight(Gfx.FONT_XTINY);
        var bgH = dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM);
        if (bgH > 88) {
            bgH = dc.getFontHeight(Gfx.FONT_NUMBER_MILD);
        }

        MillimetreDrawing.drawSheet(dc, state);
        var afterHeader = MillimetreDrawing.drawHeader(dc, pad, datum, timeString, steps, heartrate);

        // Stamp upper-right, 13 millimetre cells below the header rule
        MillimetreDrawing.drawModeStamp(
            dc, pad, afterHeader - tinyH - 2 + (13 * MillimetreDrawing.CELL),
            anzeigeMode, state
        );

        // Extra bottom inset: Venu X1 rounded bezel ate the old single-line footer
        var footerH = tinyH + 16;
        var footerY = height - pad - footerH - 4;
        var alert = (state == MillimetreDrawing.STATE_HYPO || state == MillimetreDrawing.STATE_HYPER);
        var alertReserve = alert ? (tinyH + 8) : 0;

        var gluY = afterHeader + 4;
        var gluBlockH = MillimetreDrawing.drawGlucoseInk(dc, pad, gluY, sgvTextOrDash(anzeigeSGV), auswahlPfeil, state);

        var graphY = gluY + gluBlockH + 4;
        var graphH = footerY - alertReserve - graphY - 6;
        if (graphH < 140) { graphH = 140; }
        if (graphH > 220) { graphH = 220; }

        MillimetreDrawing.drawLabPlot(
            dc, pad, graphY, width - 2 * pad, graphH,
            past, future, pastTs, targetNum, basalSteps, smbTs, state
        );

        if (alert) {
            MillimetreDrawing.drawPredictHint(dc, cx, footerY - tinyH - 4, predict15, state);
        }
        MillimetreDrawing.drawFooter(dc, pad, footerY, width - 2 * pad, anzeigeIOB, anzeigeBasal, deltaNum, tir);

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, graphY - tinyH, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    function sgvTextOrDash(anzeigeSGV) {
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            return anzeigeSGV;
        }
        return "--";
    }

    function deltaFromAaps(punkte, anzeigeDelta) {
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["delta"] != null) {
            var raw = punkte[0]["delta"].toNumber();
            if (raw != null) { return raw; }
        }
        return parseDelta(anzeigeDelta);
    }

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

    function mockFuture(past, sgv, delta, state) {
        var out = [];
        var base = sgv != null ? sgv : 120;
        if (past != null && past.size() > 0) {
            base = past[past.size() - 1];
        }
        var step = delta;
        if (step == null) { step = 0; }
        var drift = step;
        if (state == MillimetreDrawing.STATE_HYPO && drift > -1) { drift = -3; }
        if (state == MillimetreDrawing.STATE_HYPER && drift < 1) { drift = 4; }
        for (var i = 1; i <= 12; i++) {
            var v = base + ((drift * i) / 2);
            if (v < 40) { v = 40; }
            if (v > 400) { v = 400; }
            out.add(v.toNumber());
        }
        return out;
    }

    //! Returns [sgvArray, timestampSecArray] chronological oldest→newest.
    function buildGraphWithTs(punkte) {
        var out = [];
        var tsOut = [];
        if (bgReadingsAccumulated != null && bgReadingsAccumulated instanceof Lang.Array) {
            var n = bgReadingsAccumulated.size();
            var start = 0;
            if (n > 36) { start = n - 36; }
            for (var i = n - 1; i >= start; i--) {
                if (bgReadingsAccumulated[i] != null && bgReadingsAccumulated[i]["sgv"] != null) {
                    var v = bgReadingsAccumulated[i]["sgv"].toNumber();
                    if (v != null && v >= 20 && v <= 600) {
                        out.add(v);
                        var d = bgReadingsAccumulated[i]["date"];
                        if (d != null) {
                            var sec = d.toNumber();
                            if (sec != null && sec > 100000000000.0) {
                                sec = (sec / 1000.0).toNumber();
                            }
                            tsOut.add(sec);
                        } else {
                            tsOut.add(null);
                        }
                    }
                }
            }
        }
        if (out.size() < 2 && punkte != null && punkte instanceof Lang.Array) {
            out = [];
            tsOut = [];
            for (var j = punkte.size() - 1; j >= 0; j--) {
                if (punkte[j] != null && punkte[j]["sgv"] != null) {
                    var v2 = punkte[j]["sgv"].toNumber();
                    if (v2 != null && v2 >= 20 && v2 <= 600) {
                        out.add(v2);
                        var d2 = punkte[j]["date"];
                        if (d2 != null) {
                            var sec2 = d2.toNumber();
                            if (sec2 != null && sec2 > 100000000000.0) {
                                sec2 = (sec2 / 1000.0).toNumber();
                            }
                            tsOut.add(sec2);
                        } else {
                            tsOut.add(null);
                        }
                    }
                }
            }
        }
        return [out, tsOut];
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
