using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

//! CONCEPT C — Blueprint drawing helpers (layoutStyle=6).
//! Technical blueprint aesthetic: deep-blue grid, oscilloscope trace with
//! dashed thresholds, railway signal lights, monospace-style data table,
//! status bar. Alert language mirrors the Pilot concept.
module BlueprintDrawing {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;
    const STATE_HYPER = 3;

    //! Blueprint palette
    const COL_BG = 0x0A1C44;
    const COL_GRID = 0x143063;
    const COL_TRACE = 0x35E0FF;
    const COL_PREDICT = 0xFFFFFF;
    const COL_THRESH = 0x7E93C4;
    const COL_TGTBAND = 0x1D4C96;
    const COL_LABEL = 0xBFD4FF;
    const COL_VALUE = 0xFFFFFF;
    const COL_CYAN = 0x7FDBFF;
    const COL_LINE = 0x3A5A96;
    const COL_AMBER_BG = 0xC77F1A;
    const COL_AMBER_TXT = 0x0A1C44;
    const COL_GREEN = 0x00C853;
    const COL_RED = 0xFF3D57;
    const COL_ORANGE = 0xFF8C00;
    const COL_DIM_GREEN = 0x0E3A22;
    const COL_DIM_AMBER = 0x4A2E08;
    const COL_DIM_RED = 0x4A1218;

    function stateFromSgv(sgv, low, hyper) {
        if (sgv == null) { return STATE_NORMAL; }
        var v = sgv.toNumber();
        if (v == null || v < 20 || v > 600) { return STATE_NORMAL; }
        var lo = low != null ? low.toNumber() : 70;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return STATE_HYPO; }
        if (v >= hy) { return STATE_HYPER; }
        return STATE_NORMAL;
    }

    //! Deep-blue blueprint background + fine grid + hypo/hyper vignette.
    function drawBlueprintBackground(dc, state) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(COL_GRID, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var gx = 0;
        while (gx <= w) {
            dc.drawLine(gx, 0, gx, h);
            gx += 24;
        }
        var gy = 0;
        while (gy <= h) {
            dc.drawLine(0, gy, w, gy);
            gy += 24;
        }
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        var topC = state == STATE_HYPO ? 0x330000 : 0x332000;
        var band = 60;
        if (band > h / 5) { band = h / 5; }
        var y = 0;
        while (y < band) {
            var ratio = (band - y).toFloat() / band.toFloat();
            var c = mixTowardBlack(topC, ratio * 0.5);
            dc.setColor(c, c);
            dc.drawLine(0, y, w, y);
            y++;
        }
        y = h - band;
        while (y < h) {
            var ratio2 = (y - (h - band)).toFloat() / band.toFloat();
            var c2 = mixTowardBlack(topC, ratio2 * 0.5);
            dc.setColor(c2, c2);
            dc.drawLine(0, y, w, y);
            y++;
        }
    }

    function mixTowardBlack(color, amount) {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        var f = amount;
        if (f < 0) { f = 0; }
        if (f > 1) { f = 1; }
        return (((r * f).toNumber() << 16) | ((g * f).toNumber() << 8) | (b * f).toNumber());
    }

    //! Horizontal dashed line (thresholds).
    function drawDashedLine(dc, x1, y, x2, dashLen, gapLen) {
        var x = x1;
        while (x < x2) {
            var xe = x + dashLen;
            if (xe > x2) { xe = x2; }
            dc.drawLine(x, y, xe, y);
            x = xe + gapLen;
        }
    }

    //! Header: datum left, time centered, steps · HR right (pilot convention).
    function drawHeader(dc, pad, datum, timeString, steps, heartrate) {
        var w = dc.getWidth();
        var y = pad;
        dc.setColor(COL_LABEL, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, y, Gfx.FONT_XTINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        dc.setColor(COL_VALUE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Gfx.FONT_XTINY, timeString, Gfx.TEXT_JUSTIFY_CENTER);
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.setColor(COL_LABEL, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - pad, y, Gfx.FONT_XTINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);
    }

    //! Amber mode tag, right-aligned. Hidden when mode is null/empty.
    //! Returns the tag height used (0 when hidden).
    function drawModeTag(dc, pad, y, mode) {
        if (mode == null || mode.equals("") ) { return 0; }
        var txt = "MODE: " + mode;
        var tw = dc.getTextWidthInPixels(txt, Gfx.FONT_XTINY);
        var pw = tw + 20;
        var ph = 24;
        var px = dc.getWidth() - pad - pw;
        dc.setColor(COL_AMBER_BG, COL_AMBER_BG);
        dc.fillRoundedRectangle(px, y, pw, ph, 12);
        dc.setColor(COL_AMBER_TXT, Gfx.COLOR_TRANSPARENT);
        dc.drawText(px + pw / 2, y + ph / 2, Gfx.FONT_XTINY, txt,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        return ph;
    }

    //! Oscilloscope trace: 3h history + dotted +60m prediction (mandatory),
    //! dashed +180/+70 guides (no text labels), tagged TGT band.
    function drawOscilloscope(dc, x, y, w, h, past, future, targetNum, state) {
        if (past == null || past.size() < 2) { return; }
        var gmin = 500;
        var gmax = 0;
        var i = 0;
        while (i < past.size()) {
            if (past[i] < gmin) { gmin = past[i]; }
            if (past[i] > gmax) { gmax = past[i]; }
            i++;
        }
        if (future != null) {
            i = 0;
            while (i < future.size()) {
                if (future[i] < gmin) { gmin = future[i]; }
                if (future[i] > gmax) { gmax = future[i]; }
                i++;
            }
        }
        if (gmax - gmin < 40) {
            var mid = (gmax + gmin) / 2;
            gmin = mid - 20;
            gmax = mid + 20;
        }
        // Silent clinical guides (no "+180/+70 THRESHOLD" text — frees the plot)
        var yHi = y + h - (((180 - gmin).toFloat() / (gmax - gmin).toFloat()) * h).toNumber();
        var yLo = y + h - (((70 - gmin).toFloat() / (gmax - gmin).toFloat()) * h).toNumber();
        if (yHi >= y && yHi <= y + h) {
            dc.setColor(COL_THRESH, Gfx.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            drawDashedLine(dc, x, yHi, x + w, 8, 6);
        }
        if (yLo >= y && yLo <= y + h) {
            dc.setColor(COL_THRESH, Gfx.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            drawDashedLine(dc, x, yLo, x + w, 8, 6);
        }
        // Target band (target ±10 mg/dL) tagged on its left edge
        if (targetNum != null) {
            var yT2 = y + h - (((targetNum + 10 - gmin).toFloat() / (gmax - gmin).toFloat()) * h).toNumber();
            var yT1 = y + h - (((targetNum - 10 - gmin).toFloat() / (gmax - gmin).toFloat()) * h).toNumber();
            if (yT2 < y) { yT2 = y; }
            if (yT1 > y + h) { yT1 = y + h; }
            if (yT1 > yT2) {
                // Silent band only — numeric TGT lives in the data table (avoid duplicate label)
                dc.setColor(COL_TGTBAND, COL_TGTBAND);
                dc.fillRectangle(x, yT2, w, yT1 - yT2);
            }
        }
        var pastW = (w * 0.75).toNumber();
        var futW = w - pastW;
        var pastPts = [];
        i = 0;
        while (i < past.size()) {
            var px = x + ((i.toFloat() / (past.size() - 1).toFloat()) * pastW).toNumber();
            var norm = (past[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py = y + h - (norm * h).toNumber();
            pastPts.add([px, py]);
            i++;
        }
        var futPts = [];
        if (future != null && future.size() >= 2) {
            i = 0;
            while (i < future.size()) {
                var px2 = x + pastW + ((i.toFloat() / (future.size() - 1).toFloat()) * futW).toNumber();
                var norm2 = (future[i] - gmin).toFloat() / (gmax - gmin).toFloat();
                var py2 = y + h - (norm2 * h).toNumber();
                futPts.add([px2, py2]);
                i++;
            }
        }
        // Past trace (cyan, with dots)
        dc.setColor(COL_TRACE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        i = 0;
        while (i < pastPts.size() - 1) {
            dc.drawLine(pastPts[i][0], pastPts[i][1], pastPts[i + 1][0], pastPts[i + 1][1]);
            i++;
        }
        i = 0;
        while (i < pastPts.size()) {
            dc.fillCircle(pastPts[i][0], pastPts[i][1], 2);
            i++;
        }
        // Future: dotted +60m prediction (always drawn)
        var futC = COL_PREDICT;
        if (state == STATE_HYPO) { futC = 0xFF8C8C; }
        else if (state == STATE_HYPER) { futC = 0xFFCC88; }
        dc.setColor(futC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        if (futPts.size() >= 2) {
            if (pastPts.size() > 0) {
                dc.drawLine(pastPts[pastPts.size() - 1][0], pastPts[pastPts.size() - 1][1], futPts[0][0], futPts[0][1]);
            }
            i = 0;
            while (i < futPts.size() - 1) {
                if ((i % 2) == 0) {
                    dc.drawLine(futPts[i][0], futPts[i][1], futPts[i + 1][0], futPts[i + 1][1]);
                }
                i++;
            }
        }
        // Compact predict cue (no -3H/-2H axis — reclaim vertical space below graph)
        dc.setColor(COL_LABEL, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w, y + 2, Gfx.FONT_XTINY, "+60m", Gfx.TEXT_JUSTIFY_RIGHT);
        // Thin NOW divider between history and forecast
        dc.setColor(COL_GRID, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x + pastW, y + 4, x + pastW, y + h - 4);
    }

    //! Railway signal lights: green/amber/red, only the active one lit.
    //! Compact stack + short caption so it never spills into the data table.
    function drawSignalLights(dc, x, y, state) {
        var r = 6;
        var gap = 18;
        var cols = [COL_GREEN, COL_ORANGE, COL_RED];
        var dims = [COL_DIM_GREEN, COL_DIM_AMBER, COL_DIM_RED];
        var lit = 0;
        if (state == STATE_HYPO) { lit = 2; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { lit = 1; }
        var k = 0;
        while (k < 3) {
            var c = dims[k];
            if (k == lit) { c = cols[k]; }
            dc.setColor(c, c);
            dc.fillCircle(x, y + k * gap, r);
            k++;
        }
        // Short caption (XTINY); "OK" when in range — avoids overlapping TIR row
        var cap = "OK";
        var capC = COL_GREEN;
        if (state == STATE_HYPO) { cap = "LOW"; capC = COL_RED; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { cap = "HIGH"; capC = COL_ORANGE; }
        dc.setColor(capC, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, y + 3 * gap + 1, Gfx.FONT_XTINY, cap, Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Glucose readout: slightly smaller digits, trend arrow to the RIGHT.
    function drawGlucoseBlueprint(dc, cx, y, sgvText, auswahlPfeil, state) {
        var col = COL_VALUE;
        // Prefer MEDIUM over HOT — leaves room for the side arrow without crowding.
        var fontBg = Gfx.FONT_NUMBER_MEDIUM;
        var bgH = dc.getFontHeight(fontBg);
        if (bgH > 88) {
            fontBg = Gfx.FONT_NUMBER_MILD;
            bgH = dc.getFontHeight(fontBg);
        }
        var bgY = y;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_CENTER);
        var tw = dc.getTextWidthInPixels(sgvText, fontBg);
        var ah = 24;
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            var ax = cx + (tw / 2) + 8;
            var ay = bgY + ((bgH - ah) / 2).toNumber();
            dc.drawScaledBitmap(ax, ay, ah, ah, bmp);
        }
        if (state == STATE_HYPO) {
            dc.setColor(COL_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 14, Gfx.FONT_XTINY, "LOW · <70", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_HYPER) {
            dc.setColor(COL_ORANGE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 14, Gfx.FONT_XTINY, "HIGH GLUCOSE", Gfx.TEXT_JUSTIFY_CENTER);
        }
        return bgY + bgH;
    }

    //! Compact 3x2 data table (smaller rows + XTINY labels).
    //! Row 3 right cell = current target (mg/dL) from AAPS `target`.
    function drawDataTable(dc, x, y, w, tir, deltaNum, iob, ageMin, basal, targetNum) {
        var rowH = 24;
        var rows = 3;
        var th = rowH * rows;
        dc.setColor(COL_LINE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, y, w, th);
        dc.drawLine(x + w / 2, y, x + w / 2, y + th);
        var r = 1;
        while (r < rows) {
            dc.drawLine(x, y + r * rowH, x + w, y + r * rowH);
            r++;
        }
        var fnt = Gfx.FONT_XTINY;
        // Row 1: TIR | delta
        drawTableCell(dc, x, y, w / 2, rowH, fnt, "TIR", tir.toString() + "%");
        var dStr = "Δ --";
        if (deltaNum != null) {
            dStr = deltaNum > 0 ? ("Δ +" + deltaNum.toString()) : ("Δ " + deltaNum.toString());
        }
        drawTableValue(dc, x + w / 2, y, w / 2, rowH, fnt, dStr);
        // Row 2: IOB | age
        var iobV = "-- U";
        if (iob != null && iob.equals("") == false) { iobV = iob; }
        drawTableCell(dc, x, y + rowH, w / 2, rowH, fnt, "IOB", iobV);
        var ageV = "--";
        if (ageMin != null) { ageV = ageMin.toString() + " min"; }
        drawTableValue(dc, x + w / 2, y + rowH, w / 2, rowH, fnt, ageV);
        // Row 3: TBR | targetBg
        var tbrV = "--";
        if (basal != null && basal.equals("") == false && basal.equals("-- %") == false) { tbrV = basal; }
        drawTableCell(dc, x, y + 2 * rowH, w / 2, rowH, fnt, "TBR", tbrV);
        var tgtV = "--";
        if (targetNum != null) { tgtV = "TGT " + targetNum.toString(); }
        drawTableValue(dc, x + w / 2, y + 2 * rowH, w / 2, rowH, fnt, tgtV);
    }

    //! Left table cell: cyan label + white value.
    function drawTableCell(dc, x, y, w, h, fnt, label, value) {
        var cy = y + h / 2;
        dc.setColor(COL_CYAN, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + 8, cy, fnt, label, Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        var lw = dc.getTextWidthInPixels(label, fnt);
        dc.setColor(COL_VALUE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + 8 + lw + 6, cy, fnt, value, Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Right table cell: single centered white value.
    function drawTableValue(dc, x, y, w, h, fnt, value) {
        dc.setColor(COL_VALUE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + h / 2, fnt, value, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Status bar: compact XTINY line that always fits the bar width.
    function drawStatusBar(dc, x, y, w, state, targetNum, mode) {
        var bh = 20;
        dc.setColor(COL_TGTBAND, COL_TGTBAND);
        dc.fillRoundedRectangle(x, y, w, bh, 5);
        dc.setColor(COL_LINE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, bh, 5);
        // Glucose zone for the face (not AAPS profile / therapy mode)
        var stLabel = "IN RANGE";
        if (state == STATE_HYPO) { stLabel = "HYPO"; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { stLabel = "HIGH"; }
        var fnt = Gfx.FONT_XTINY;
        var maxW = w - 10;
        // Build longest → shortest until it fits (no clipping on rounded edges)
        var candidates = [
            stLabel + " · SENSOR OK" +
                ((mode != null && mode.equals("") == false) ? (" · " + mode) : ""),
            stLabel + " · SENSOR OK",
            stLabel
        ];
        var st = candidates[candidates.size() - 1];
        var ci = 0;
        while (ci < candidates.size()) {
            if (dc.getTextWidthInPixels(candidates[ci], fnt) <= maxW) {
                st = candidates[ci];
                break;
            }
            ci++;
        }
        dc.setColor(COL_LABEL, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + bh / 2, fnt, st,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! 15-minute prediction hint, alert states only (pilot language).
    function drawPredictHint(dc, cx, y, predict15, state) {
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        if (predict15 == null) { return; }
        var col = state == STATE_HYPO ? 0xFF8C8C : 0xFFCC88;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, "→ " + predict15.toString() + " in 15m", Gfx.TEXT_JUSTIFY_CENTER);
    }

}
