using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

//! CONCEPT B — Pilot drawing helpers (target band, predictive sparkline, double ring).
module PilotDrawing {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;
    const STATE_HYPER = 3;

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

    function edgeInsetX(y, width, height, isRound) {
        if (isRound == false) {
            return width >= 400 ? 16 : 12;
        }
        var r = width / 2.0;
        var cy = height / 2.0;
        var dy = y.toFloat() - cy;
        var inside = r * r - dy * dy;
        if (inside <= 0) { return (width * 0.20).toNumber(); }
        var inset = (width / 2.0 - Math.sqrt(inside)).toNumber() + 8;
        if (inset < 16) { inset = 16; }
        return inset;
    }

    function drawTopBar(dc, pad, datum, steps, heartrate) {
        var w = dc.getWidth();
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, pad, Gfx.FONT_XTINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(w - pad, pad, Gfx.FONT_XTINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);
    }

    function drawTargetBand(dc, x, y, w, h) {
        dc.setColor(0x2A2A2A, 0x2A2A2A);
        dc.fillRectangle(x, y, w, h);
        dc.setColor(0x444444, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, y, w, h);
    }

    function drawPredictiveSparkline(dc, x, y, w, h, past, future, state) {
        if (past == null || past.size() < 2) { return; }
        var gmin = 500;
        var gmax = 0;
        for (var i = 0; i < past.size(); i++) {
            if (past[i] < gmin) { gmin = past[i]; }
            if (past[i] > gmax) { gmax = past[i]; }
        }
        if (future != null) {
            for (var i = 0; i < future.size(); i++) {
                if (future[i] < gmin) { gmin = future[i]; }
                if (future[i] > gmax) { gmax = future[i]; }
            }
        }
        if (gmax - gmin < 40) {
            var mid = (gmax + gmin) / 2;
            gmin = mid - 20;
            gmax = mid + 20;
        }
        var pastW = (w * 0.75).toNumber();
        var futW = w - pastW;

        var pastPts = [];
        for (var i = 0; i < past.size(); i++) {
            var px = x + ((i.toFloat() / (past.size() - 1).toFloat()) * pastW).toNumber();
            var norm = (past[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py = y + h - (norm * h).toNumber();
            pastPts.add([px, py]);
        }
        var futPts = [];
        if (future != null && future.size() >= 2) {
            for (var i = 0; i < future.size(); i++) {
                var px2 = x + pastW + ((i.toFloat() / (future.size() - 1).toFloat()) * futW).toNumber();
                var norm2 = (future[i] - gmin).toFloat() / (gmax - gmin).toFloat();
                var py2 = y + h - (norm2 * h).toNumber();
                futPts.add([px2, py2]);
            }
        }

        var fillC = state == STATE_NORMAL ? 0x112233 : 0x222222;
        dc.setColor(fillC, Gfx.COLOR_TRANSPARENT);
        for (var i = 0; i < pastPts.size() - 1; i++) {
            dc.fillPolygon([
                [pastPts[i][0], pastPts[i][1]],
                [pastPts[i + 1][0], pastPts[i + 1][1]],
                [pastPts[i + 1][0], y + h],
                [pastPts[i][0], y + h]
            ]);
        }

        var lineC = state == STATE_NORMAL ? 0x2C8EFF : 0xFFFFFF;
        dc.setColor(lineC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < pastPts.size() - 1; i++) {
            dc.drawLine(pastPts[i][0], pastPts[i][1], pastPts[i + 1][0], pastPts[i + 1][1]);
        }

        // Future dotted
        var futC = 0xFFFFFF;
        if (state == STATE_HYPO) { futC = 0xFF8C8C; }
        else if (state == STATE_HYPER) { futC = 0xFFCC88; }
        dc.setColor(futC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        if (futPts.size() >= 2) {
            // Connect last past to first future
            if (pastPts.size() > 0) {
                dc.drawLine(pastPts[pastPts.size() - 1][0], pastPts[pastPts.size() - 1][1], futPts[0][0], futPts[0][1]);
            }
            for (var i = 0; i < futPts.size() - 1; i++) {
                if ((i % 2) == 0) {
                    dc.drawLine(futPts[i][0], futPts[i][1], futPts[i + 1][0], futPts[i + 1][1]);
                }
            }
        }

        dc.setColor(0xAAAAAA, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, y + h + 1, Gfx.FONT_XTINY, "3h", Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + w, y + h + 1, Gfx.FONT_XTINY, "+60m", Gfx.TEXT_JUSTIFY_RIGHT);
    }

    function drawDoubleRing(dc, cx, cy, outerR, innerR, tir, delta, state) {
        var outerCol = 0x00C853;
        if (state == STATE_HYPO) { outerCol = 0xFF3D57; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { outerCol = 0xFF8C00; }

        var gapStart = 225;
        var gapEnd = 315;
        var sweep = 270;
        var tirA = ((tir.toFloat() / 100.0) * sweep).toNumber();
        if (tirA > sweep) { tirA = sweep; }

        dc.setPenWidth(10);
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
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
            for (var i = 0; i < 16; i++) {
                var a = gapStart - ((i.toFloat() / 15.0) * sweep).toNumber();
                while (a < 0) { a += 360; }
                var rad = a * Math.PI / 180.0;
                var x1 = cx + (outerR - 8) * Math.cos(rad);
                var y1 = cy - (outerR - 8) * Math.sin(rad);
                var x2 = cx + (outerR + 5) * Math.cos(rad);
                var y2 = cy - (outerR + 5) * Math.sin(rad);
                dc.drawLine(x1.toNumber(), y1.toNumber(), x2.toNumber(), y2.toNumber());
            }
        }

        // Inner delta ring (-10..+10 → 0..270°)
        var d = delta;
        if (d == null) { d = 0; }
        if (d < -10) { d = -10; }
        if (d > 10) { d = 10; }
        var deltaA = (((d + 10).toFloat() / 20.0) * sweep).toNumber();
        dc.setPenWidth(4);
        dc.setColor(0x222222, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, innerR, Gfx.ARC_CLOCKWISE, gapStart, gapEnd);
        if (deltaA > 2) {
            var dEnd = gapStart - deltaA;
            while (dEnd < 0) { dEnd += 360; }
            dc.setColor(0x2C8EFF, Gfx.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, innerR, Gfx.ARC_CLOCKWISE, gapStart, dEnd);
        }
    }

    function drawGlucosePilot(dc, cx, cy, sgvText, auswahlPfeil, anzeigeDelta, state) {
        var col = 0x2C8EFF;
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

        // Arrow centered under glucose (delta already shown as Δ below ring)
        var ah = 28;
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            var ax = cx - ah / 2;
            var ay = bgY + bgH - 2;
            dc.drawScaledBitmap(ax, ay, ah, ah, bmp);
        }

        if (state == STATE_HYPO) {
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 14, Gfx.FONT_XTINY, "LOW · <70", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_HYPER) {
            dc.setColor(0xFF8C00, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 14, Gfx.FONT_XTINY, "HIGH GLUCOSE", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    //! y is absolute baseline for TIR / Δ (already below ring).
    function drawRingLabels(dc, cx, y, outerR, tir, delta) {
        var xOff = (outerR * 0.78).toNumber();
        if (xOff < 70) { xOff = 70; }
        dc.setColor(0x00C853, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx - xOff, y, Gfx.FONT_XTINY, tir.toString() + "% TIR", Gfx.TEXT_JUSTIFY_CENTER);
        var dStr = "Δ --";
        if (delta != null) {
            dStr = delta > 0 ? ("Δ +" + delta.toString()) : ("Δ " + delta.toString());
        }
        dc.setColor(0x2C8EFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx + xOff, y, Gfx.FONT_XTINY, dStr, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawTechLine(dc, cx, y, iob, basal, cob, ageMin) {
        var tech = "";
        if (iob != null && iob.equals("") == false) { tech = iob; }
        if (basal != null && basal.equals("") == false && basal.equals("-- %") == false) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + basal;
        }
        if (cob != null && cob.equals("") == false && cob.equals("-- g") == false) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + cob;
        }
        if (ageMin != null) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + ageMin.toString() + "m";
        }
        if (tech.equals("")) { return; }
        dc.setColor(0xCCCCCC, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, tech, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawBottomPill(dc, state, version) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bh = 30;
        var bw = 180;
        var by = h - bh - 18;
        var bx = w / 2 - bw / 2;
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
        dc.fillRoundedRectangle(bx, by, bw, bh, 14);
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, by + bh / 2, Gfx.FONT_XTINY, txt, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        return by;
    }

    function drawPredictHint(dc, cx, y, predict15, state) {
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        if (predict15 == null) { return; }
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, "PREDICT 15min → " + predict15.toString(), Gfx.TEXT_JUSTIFY_CENTER);
    }

}
