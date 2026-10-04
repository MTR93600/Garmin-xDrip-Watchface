using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

//! CONCEPT C — Cockpit TIR drawing helpers (layoutStyle=7).
//! Hero TIR ring + compact graph band (3h + dotted +60m prediction) + data tiles.
//! Alert states reuse the Pilot visual language (vignette, ring color, white glucose).
module CockpitDrawing {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;
    const STATE_HYPER = 3;

    const COL_GREEN = 0x00C853;
    const COL_RED = 0xFF3D57;
    const COL_ORANGE = 0xFF8C00;
    const COL_BLUE = 0x2C8EFF;
    const COL_AMBER = 0xFFB020;
    const COL_CYAN = 0x33DDFF;
    const COL_TILE_BG = 0x141414;
    const COL_TILE_BORDER = 0x2E2E2E;

    function drawVignetteBackground(dc, state) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x000000, 0x000000);
        dc.fillRectangle(0, 0, w, h);
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        var topC = state == STATE_HYPO ? 0x330000 : 0x332000;
        var band = 60;
        if (band > h / 5) { band = h / 5; }
        for (var y = 0; y < band; y++) {
            var ratio = (band - y).toFloat() / band.toFloat();
            dc.setColor(mixTowardBlack(topC, ratio * 0.5), mixTowardBlack(topC, ratio * 0.5));
            dc.drawLine(0, y, w, y);
        }
        for (var y = h - band; y < h; y++) {
            var ratio2 = (y - (h - band)).toFloat() / band.toFloat();
            dc.setColor(mixTowardBlack(topC, ratio2 * 0.5), mixTowardBlack(topC, ratio2 * 0.5));
            dc.drawLine(0, y, w, y);
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

    //! Top strip: datum left, time centered (+ amber mode chip when a mode runs), steps · HR right.
    function drawTopStrip(dc, pad, datum, timeString, mode, steps, heartrate) {
        var w = dc.getWidth();
        var y = pad;
        var h = 36;
        var cy = y + h / 2;
        dc.setColor(0x1A1A1A, 0x1A1A1A);
        dc.fillRoundedRectangle(pad, y, w - 2 * pad, h, 18);

        if (datum != null) {
            dc.setColor(0xCCCCCC, Gfx.COLOR_TRANSPARENT);
            dc.drawText(pad + 12, cy, Gfx.FONT_XTINY, datum, Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - pad - 12, cy, Gfx.FONT_XTINY, stepsStr + " · " + hrStr,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);

        var modeStr = null;
        if (mode != null) {
            modeStr = mode.toString();
            if (modeStr == null || modeStr.equals("")) { modeStr = null; }
        }
        var fontT = Gfx.FONT_NUMBER_MILD;
        var tw = dc.getTextWidthInPixels(timeString, fontT);
        var chipW = 0;
        if (modeStr != null) {
            chipW = dc.getTextWidthInPixels(modeStr, Gfx.FONT_XTINY) + 20;
        }
        var totalW = tw + (modeStr != null ? 8 + chipW : 0);
        var sx = (w - totalW) / 2;
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(sx, cy, fontT, timeString, Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        if (modeStr != null) {
            var chX = sx + tw + 8;
            var chH = 22;
            var chY = cy - chH / 2;
            dc.setColor(COL_AMBER, COL_AMBER);
            dc.fillRoundedRectangle(chX, chY, chipW, chH, 11);
            dc.setColor(0x000000, Gfx.COLOR_TRANSPARENT);
            dc.drawText(chX + chipW / 2, cy, Gfx.FONT_XTINY, modeStr,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Hero TIR ring — same 270° sweep / bottom gap as PilotDrawing.drawDoubleRing.
    function drawTirRing(dc, cx, cy, outerR, tir, state) {
        var outerCol = COL_GREEN;
        if (state == STATE_HYPO) { outerCol = COL_RED; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { outerCol = COL_ORANGE; }

        var gapStart = 225;
        var gapEnd = 315;
        var sweep = 270;
        var t = tir != null ? tir : 0;
        var tirA = ((t.toFloat() / 100.0) * sweep).toNumber();
        if (tirA > sweep) { tirA = sweep; }

        dc.setPenWidth(12);
        dc.setColor(0x222222, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, outerR, Gfx.ARC_CLOCKWISE, gapStart, gapEnd);
        if (tirA > 2) {
            var fillEnd = gapStart - tirA;
            while (fillEnd < 0) { fillEnd += 360; }
            dc.setColor(outerCol, Gfx.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, outerR, Gfx.ARC_CLOCKWISE, gapStart, fillEnd);
        }

        // HYPO ticks
        if (state == STATE_HYPO) {
            dc.setPenWidth(2);
            dc.setColor(COL_RED, Gfx.COLOR_TRANSPARENT);
            for (var i = 0; i < 16; i++) {
                var a = gapStart - ((i.toFloat() / 15.0) * sweep).toNumber();
                while (a < 0) { a += 360; }
                var rad = a * Math.PI / 180.0;
                var x1 = cx + (outerR - 10) * Math.cos(rad);
                var y1 = cy - (outerR - 10) * Math.sin(rad);
                var x2 = cx + (outerR + 6) * Math.cos(rad);
                var y2 = cy - (outerR + 6) * Math.sin(rad);
                dc.drawLine(x1.toNumber(), y1.toNumber(), x2.toNumber(), y2.toNumber());
            }
        }
    }

    function drawTirLabel(dc, cx, y, tir, state) {
        var col = COL_GREEN;
        if (state == STATE_HYPO) { col = COL_RED; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { col = COL_ORANGE; }
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, tir.toString() + "% TIR", Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawGlucoseCockpit(dc, cx, cy, sgvText, auswahlPfeil, state) {
        var col = COL_BLUE;
        if (state == STATE_HYPO || state == STATE_HYPER) { col = 0xFFFFFF; }
        var fontBg = Gfx.FONT_NUMBER_HOT;
        var bgH = dc.getFontHeight(fontBg);
        if (bgH > 96) {
            fontBg = Gfx.FONT_NUMBER_MEDIUM;
            bgH = dc.getFontHeight(fontBg);
        }
        var bgY = cy - (bgH / 2).toNumber() - 6;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_CENTER);

        // Trend arrow centered under glucose
        var ah = 28;
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            dc.drawScaledBitmap(cx - ah / 2, bgY + bgH - 2, ah, ah, bmp);
        }

        if (state == STATE_HYPO) {
            dc.setColor(COL_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 14, Gfx.FONT_XTINY, "LOW · <70", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_HYPER) {
            dc.setColor(COL_ORANGE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 14, Gfx.FONT_XTINY, "HIGH GLUCOSE", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Compact graph band: target zone + 3h curve + dotted +60m prediction + time labels.
    function drawGraphBand(dc, x, y, w, h, past, future, targetNum, state) {
        dc.setColor(0x12161C, 0x12161C);
        dc.fillRoundedRectangle(x, y, w, h, 12);
        dc.setColor(0x2A2A2A, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 12);
        if (past == null || past.size() < 2) { return; }

        var ix = x + 8;
        var iy = y + 8;
        var iw = w - 16;
        var ih = h - 30; // room for time labels

        var gmin = 500;
        var gmax = 0;
        for (var i = 0; i < past.size(); i++) {
            if (past[i] < gmin) { gmin = past[i]; }
            if (past[i] > gmax) { gmax = past[i]; }
        }
        if (future != null) {
            for (var j = 0; j < future.size(); j++) {
                if (future[j] < gmin) { gmin = future[j]; }
                if (future[j] > gmax) { gmax = future[j]; }
            }
        }
        if (gmax - gmin < 40) {
            var mid = (gmax + gmin) / 2;
            gmin = mid - 20;
            gmax = mid + 20;
        }

        // Target zone (shaded band + tag), drawn under the curve
        if (targetNum != null) {
            var t = targetNum;
            if (t >= gmin && t <= gmax) {
                var tnorm = (t - gmin).toFloat() / (gmax - gmin).toFloat();
                var ty = iy + ih - (tnorm * ih).toNumber();
                dc.setColor(0x1D2B33, 0x1D2B33);
                dc.fillRectangle(ix, ty - 9, iw, 18);
                dc.setColor(0x7FB3C8, Gfx.COLOR_TRANSPARENT);
                dc.drawText(ix + 4, ty, Gfx.FONT_XTINY, "TGT " + t.toString(),
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
            }
        }

        var pastW = (iw * 0.75).toNumber();
        var futW = iw - pastW;

        var pastPts = [];
        for (var k = 0; k < past.size(); k++) {
            var px = ix + ((k.toFloat() / (past.size() - 1).toFloat()) * pastW).toNumber();
            var norm = (past[k] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py = iy + ih - (norm * ih).toNumber();
            pastPts.add([px, py]);
        }
        var futPts = [];
        if (future != null && future.size() >= 2) {
            for (var m = 0; m < future.size(); m++) {
                var px2 = ix + pastW + ((m.toFloat() / (future.size() - 1).toFloat()) * futW).toNumber();
                var norm2 = (future[m] - gmin).toFloat() / (gmax - gmin).toFloat();
                var py2 = iy + ih - (norm2 * ih).toNumber();
                futPts.add([px2, py2]);
            }
        }

        var lineC = state == STATE_NORMAL ? COL_BLUE : 0xFFFFFF;
        dc.setColor(lineC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var n = 0; n < pastPts.size() - 1; n++) {
            dc.drawLine(pastPts[n][0], pastPts[n][1], pastPts[n + 1][0], pastPts[n + 1][1]);
        }

        // Future dotted (+60m)
        var futC = 0xFFFFFF;
        if (state == STATE_HYPO) { futC = 0xFF8C8C; }
        else if (state == STATE_HYPER) { futC = 0xFFCC88; }
        dc.setColor(futC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        if (futPts.size() >= 2) {
            if (pastPts.size() > 0) {
                dc.drawLine(pastPts[pastPts.size() - 1][0], pastPts[pastPts.size() - 1][1],
                    futPts[0][0], futPts[0][1]);
            }
            for (var q = 0; q < futPts.size() - 1; q++) {
                if ((q % 2) == 0) {
                    dc.drawLine(futPts[q][0], futPts[q][1], futPts[q + 1][0], futPts[q + 1][1]);
                }
            }
        }

        dc.setColor(0x666666, Gfx.COLOR_TRANSPARENT);
        var ly = y + h - 5;
        dc.drawText(ix, ly, Gfx.FONT_XTINY, "-3h", Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(ix + pastW / 2, ly, Gfx.FONT_XTINY, "-1h", Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(ix + pastW, ly, Gfx.FONT_XTINY, "Now", Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Data tile: rounded panel, small label on top, big colored value.
    function drawTile(dc, x, y, w, h, label, value, valueCol) {
        dc.setColor(COL_TILE_BG, COL_TILE_BG);
        dc.fillRoundedRectangle(x, y, w, h, 10);
        dc.setColor(COL_TILE_BORDER, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 10);
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + 7, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_CENTER);
        var v = value != null ? value : "--";
        dc.setColor(valueCol, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + h / 2 + 7, Gfx.FONT_SMALL, v,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Loop/state pill (bottom) — Pilot family language.
    function drawStatePill(dc, cx, y, state, version) {
        var bw = 180;
        var bh = 26;
        var bx = cx - bw / 2;
        var bg = 0x1A5CFF;
        var txt = "LOOP · AAPS";
        if (state == STATE_HYPO) {
            bg = 0x8B0000;
            txt = "HYPO · AAPS";
        } else if (state == STATE_HYPER) {
            bg = 0xCC5500;
            txt = "HIGH · AAPS";
        }
        if (version != null && version.equals("") == false) {
            txt = txt + " " + version;
        }
        dc.setColor(bg, bg);
        dc.fillRoundedRectangle(bx, y, bw, bh, 13);
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y + bh / 2, Gfx.FONT_XTINY, txt,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    function drawPredictHint(dc, cx, y, predict15, state) {
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        if (predict15 == null) { return; }
        var col = state == STATE_HYPO ? 0xFF8C8C : 0xFFCC88;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, "→ " + predict15.toString() + " in 15m", Gfx.TEXT_JUSTIFY_CENTER);
    }

}
