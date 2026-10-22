using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.Time as Time;

//! CONCEPT — Millimétré (layoutStyle=9).
//! Paper millimetric lab log: cream sheet, blue/red grid, navy ink curve,
//! grey pencil +60m, green TGT highlighter, red SMB ticks, grey basal stairs,
//! rotated red mode stamp. Day skin (light AMOLED).
module MillimetreDrawing {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;
    const STATE_HYPER = 3;

    const COL_PAPER = 0xF3EBD8;
    const COL_GRID = 0x9BB8D4;
    const COL_GRID_MAJOR = 0xC45A5A;
    const COL_INK = 0x1A2A4A;
    const COL_PENCIL = 0x8A8A8A;
    const COL_PENCIL_ALERT = 0xC45A5A;
    const COL_TGT = 0xC8E6C0;
    const COL_TGT_EDGE = 0x5A9A5A;
    const COL_SMB = 0xC23030;
    const COL_BASAL = 0xB8B8B0;
    const COL_STAMP = 0xC23030;
    const COL_LABEL = 0x3A3A3A;
    const COL_DIM = 0x6A6A6A;
    const COL_RULE = 0x4A4A4A;

    //! Cell size for millimetric grid (px). Major every 10 cells.
    const CELL = 8;
    const MAJOR = 10;

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

    //! Cream sheet + blue millimetre grid + red major every 10 + optional alert frame.
    function drawSheet(dc, state) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_PAPER, COL_PAPER);
        dc.fillRectangle(0, 0, w, h);

        dc.setPenWidth(1);
        var gx = 0;
        while (gx <= w) {
            var majorX = ((gx / CELL) % MAJOR) == 0;
            dc.setColor(majorX ? COL_GRID_MAJOR : COL_GRID, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(gx, 0, gx, h);
            gx += CELL;
        }
        var gy = 0;
        while (gy <= h) {
            var majorY = ((gy / CELL) % MAJOR) == 0;
            dc.setColor(majorY ? COL_GRID_MAJOR : COL_GRID, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(0, gy, w, gy);
            gy += CELL;
        }

        if (state == STATE_HYPO || state == STATE_HYPER) {
            dc.setColor(COL_STAMP, Gfx.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawRectangle(2, 2, w - 4, h - 4);
            dc.setPenWidth(1);
            dc.drawRectangle(6, 6, w - 12, h - 12);
        }
    }

    function drawHeader(dc, pad, datum, timeString, steps, heartrate) {
        var w = dc.getWidth();
        var y = pad;
        dc.setColor(COL_LABEL, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, y, Gfx.FONT_XTINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        dc.drawText(w / 2, y, Gfx.FONT_XTINY, timeString, Gfx.TEXT_JUSTIFY_CENTER);
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(w - pad, y, Gfx.FONT_XTINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);
        var hy = y + dc.getFontHeight(Gfx.FONT_XTINY) + 4;
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad, hy, w - pad, hy);
        return hy + 4;
    }

    //! Rotated rubber-stamp (buffered bitmap + AffineTransform when available).
    function drawModeStamp(dc, pad, y, mode, state) {
        var text = null;
        if (state == STATE_HYPO) {
            text = "HYPO";
        } else if (state == STATE_HYPER) {
            text = "HYPER";
        } else if (mode != null && mode.equals("") == false) {
            text = mode.toString();
            if (text.length() > 8) {
                text = text.substring(0, 8);
            }
        }
        if (text == null) { return; }

        var fnt = Gfx.FONT_TINY;
        var tw = dc.getTextWidthInPixels(text, fnt);
        var th = dc.getFontHeight(fnt);
        var bw = tw + 20;
        var bh = th + 14;
        var px = dc.getWidth() - pad - bw - 8;
        var py = y;

        if ((Gfx has :createBufferedBitmap) && (Gfx has :AffineTransform) && (dc has :drawBitmap2)) {
            var buf = Gfx.createBufferedBitmap({:width => bw, :height => bh});
            if (buf != null) {
                var bdc = buf.getDc();
                // Transparent buffer so paper shows through the stamp frame
                bdc.setColor(Gfx.COLOR_TRANSPARENT, Gfx.COLOR_TRANSPARENT);
                bdc.clear();
                paintStamp(bdc, 0, 0, bw, bh, text, fnt);
                var bmp = buf.get();
                if (bmp != null) {
                    var transform = new Gfx.AffineTransform();
                    transform.setToTranslation((px + bw / 2).toFloat(), (py + bh / 2).toFloat());
                    transform.rotate(Math.toRadians(-8));
                    transform.translate((-bw / 2).toFloat(), (-bh / 2).toFloat());
                    dc.drawBitmap2(0, 0, bmp, {:transform => transform});
                    return;
                }
            }
        }
        // Fallback: upright stamp (devices without AffineTransform)
        paintStamp(dc, px, py, bw, bh, text, fnt);
    }

    function paintStamp(dc, x, y, w, h, text, fnt) {
        dc.setColor(COL_STAMP, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x, y, w, h);
        dc.setPenWidth(1);
        dc.drawRectangle(x + 3, y + 3, w - 6, h - 6);
        dc.drawText(x + w / 2, y + h / 2, fnt, text,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Lab plot: TGT highlighter, ink past, pencil future, SMB ticks, basal stairs.
    //! pastTimestamps: parallel array of epoch seconds (or null → index spacing).
    function drawLabPlot(dc, x, y, w, h, past, future, pastTs, targetNum, basalSteps, smbTs, state) {
        if (past == null || past.size() < 2) { return; }

        var basalH = (h * 0.18).toNumber();
        if (basalH < 14) { basalH = 14; }
        var smbH = 8;
        var plotH = h - basalH - smbH;
        if (plotH < 60) { plotH = 60; }

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

        // Target highlighter
        if (targetNum != null) {
            var yT2 = y + plotH - (((targetNum + 10 - gmin).toFloat() / (gmax - gmin).toFloat()) * plotH).toNumber();
            var yT1 = y + plotH - (((targetNum - 10 - gmin).toFloat() / (gmax - gmin).toFloat()) * plotH).toNumber();
            if (yT2 < y) { yT2 = y; }
            if (yT1 > y + plotH) { yT1 = y + plotH; }
            if (yT1 > yT2) {
                dc.setColor(COL_TGT, COL_TGT);
                dc.fillRectangle(x, yT2, w, yT1 - yT2);
                dc.setColor(COL_TGT_EDGE, Gfx.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                drawDashedLine(dc, x, yT2, x + w, 5, 4);
                drawDashedLine(dc, x, yT1, x + w, 5, 4);
                dc.setColor(COL_TGT_EDGE, Gfx.COLOR_TRANSPARENT);
                dc.drawText(x + 4, yT2 + 1, Gfx.FONT_XTINY, "TGT", Gfx.TEXT_JUSTIFY_LEFT);
            }
        }

        var pastW = (w * 0.75).toNumber();
        var futW = w - pastW;
        var nowSec = Time.now().value();
        var windowSec = 180 * 60; // 3h

        var pastPts = [];
        i = 0;
        while (i < past.size()) {
            var px;
            if (pastTs != null && pastTs.size() == past.size() && pastTs[i] != null) {
                var age = nowSec - pastTs[i];
                if (age < 0) { age = 0; }
                if (age > windowSec) { age = windowSec; }
                px = x + pastW - ((age.toFloat() / windowSec.toFloat()) * pastW).toNumber();
            } else {
                px = x + ((i.toFloat() / (past.size() - 1).toFloat()) * pastW).toNumber();
            }
            var norm = (past[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py = y + plotH - (norm * plotH).toNumber();
            pastPts.add([px, py]);
            i++;
        }

        var futPts = [];
        if (future != null && future.size() >= 2) {
            i = 0;
            while (i < future.size()) {
                var px2 = x + pastW + ((i.toFloat() / (future.size() - 1).toFloat()) * futW).toNumber();
                var norm2 = (future[i] - gmin).toFloat() / (gmax - gmin).toFloat();
                var py2 = y + plotH - (norm2 * plotH).toNumber();
                futPts.add([px2, py2]);
                i++;
            }
        }

        // Ink past
        dc.setColor(COL_INK, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        i = 0;
        while (i < pastPts.size() - 1) {
            dc.drawLine(pastPts[i][0], pastPts[i][1], pastPts[i + 1][0], pastPts[i + 1][1]);
            i++;
        }
        dc.setPenWidth(1);
        i = 0;
        while (i < pastPts.size()) {
            dc.fillCircle(pastPts[i][0], pastPts[i][1], 2);
            i++;
        }

        // Pencil future
        var pencil = (state == STATE_HYPO || state == STATE_HYPER) ? COL_PENCIL_ALERT : COL_PENCIL;
        dc.setColor(pencil, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        if (futPts.size() >= 2) {
            if (pastPts.size() > 0) {
                drawDashedSegment(dc, pastPts[pastPts.size() - 1][0], pastPts[pastPts.size() - 1][1],
                    futPts[0][0], futPts[0][1], 4, 4);
            }
            i = 0;
            while (i < futPts.size() - 1) {
                drawDashedSegment(dc, futPts[i][0], futPts[i][1], futPts[i + 1][0], futPts[i + 1][1], 4, 4);
                i++;
            }
        }
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + w, y + 2, Gfx.FONT_XTINY, "+60m", Gfx.TEXT_JUSTIFY_RIGHT);

        // SMB ticks (margin marks under curve)
        var tickY0 = y + plotH + 1;
        var tickY1 = tickY0 + smbH - 2;
        if (smbTs != null && smbTs instanceof Lang.Array) {
            dc.setColor(COL_SMB, Gfx.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            i = 0;
            while (i < smbTs.size()) {
                var ts = smbTs[i];
                if (ts != null) {
                    var tSec = ts;
                    // AAPS sends ms; watch may get Number large enough
                    if (tSec > 100000000000.0) {
                        tSec = (tSec / 1000.0).toNumber();
                    } else {
                        tSec = tSec.toNumber();
                    }
                    if (tSec != null) {
                        var ageS = nowSec - tSec;
                        if (ageS >= 0 && ageS <= windowSec) {
                            var sx = x + pastW - ((ageS.toFloat() / windowSec.toFloat()) * pastW).toNumber();
                            dc.drawLine(sx, tickY0, sx, tickY1);
                        }
                    }
                }
                i++;
            }
        }

        // Basal staircase
        var basalY = y + plotH + smbH;
        drawBasalStairs(dc, x, basalY, pastW, basalH, basalSteps, nowSec, windowSec);

        // NOW divider
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x + pastW, y + 2, x + pastW, y + h - 2);
    }

    function drawBasalStairs(dc, x, y, w, h, basalSteps, nowSec, windowSec) {
        if (basalSteps == null || !(basalSteps instanceof Lang.Array) || basalSteps.size() == 0) {
            return;
        }
        var maxP = 100;
        var i = 0;
        while (i < basalSteps.size()) {
            var step = basalSteps[i];
            if (step != null && step["p"] != null) {
                var p = step["p"].toNumber();
                if (p != null && p > maxP) { maxP = p; }
            }
            i++;
        }
        if (maxP < 100) { maxP = 100; }
        if (maxP > 300) { maxP = 300; }

        dc.setColor(COL_BASAL, COL_BASAL);
        i = 0;
        while (i < basalSteps.size()) {
            var s = basalSteps[i];
            if (s == null || s["t"] == null || s["p"] == null) {
                i++;
                continue;
            }
            var t0 = s["t"];
            if (t0 > 100000000000.0) { t0 = (t0 / 1000.0).toNumber(); }
            else { t0 = t0.toNumber(); }
            var p0 = s["p"].toNumber();
            if (t0 == null || p0 == null) { i++; continue; }

            var t1Sec = nowSec;
            if (i + 1 < basalSteps.size() && basalSteps[i + 1] != null && basalSteps[i + 1]["t"] != null) {
                var t1 = basalSteps[i + 1]["t"];
                if (t1 > 100000000000.0) { t1Sec = (t1 / 1000.0).toNumber(); }
                else { t1Sec = t1.toNumber(); }
            }
            var age0 = nowSec - t0;
            var age1 = nowSec - t1Sec;
            if (age0 < 0) { age0 = 0; }
            if (age1 < 0) { age1 = 0; }
            if (age0 > windowSec && age1 > windowSec) { i++; continue; }
            if (age0 > windowSec) { age0 = windowSec; }
            if (age1 > windowSec) { age1 = windowSec; }

            var x1 = x + w - ((age0.toFloat() / windowSec.toFloat()) * w).toNumber();
            var x0 = x + w - ((age1.toFloat() / windowSec.toFloat()) * w).toNumber();
            if (x1 < x0) {
                var tmp = x0; x0 = x1; x1 = tmp;
            }
            var barH = ((p0.toFloat() / maxP.toFloat()) * h).toNumber();
            if (barH < 1) { barH = 1; }
            if (barH > h) { barH = h; }
            var bw = x1 - x0;
            if (bw < 1) { bw = 1; }
            dc.fillRectangle(x0, y + h - barH, bw, barH);
            i++;
        }
    }

    function drawDashedLine(dc, x1, y, x2, dashLen, gapLen) {
        var x = x1;
        while (x < x2) {
            var xe = x + dashLen;
            if (xe > x2) { xe = x2; }
            dc.drawLine(x, y, xe, y);
            x = xe + gapLen;
        }
    }

    function drawDashedSegment(dc, x1, y1, x2, y2, dashLen, gapLen) {
        var dx = x2 - x1;
        var dy = y2 - y1;
        var len = Math.sqrt((dx * dx + dy * dy).toFloat());
        if (len < 1) { return; }
        var ux = dx.toFloat() / len;
        var uy = dy.toFloat() / len;
        var pos = 0.0;
        var draw = true;
        while (pos < len) {
            var seg = draw ? dashLen.toFloat() : gapLen.toFloat();
            var end = pos + seg;
            if (end > len) { end = len; }
            if (draw) {
                dc.drawLine(
                    (x1 + ux * pos).toNumber(), (y1 + uy * pos).toNumber(),
                    (x1 + ux * end).toNumber(), (y1 + uy * end).toNumber()
                );
            }
            pos = end;
            draw = !draw;
        }
    }

    //! Large inked SGV top-left + trend arrow + units.
    function drawGlucoseInk(dc, pad, y, sgvText, auswahlPfeil, state) {
        var col = COL_INK;
        if (state == STATE_HYPO) { col = COL_STAMP; }
        else if (state == STATE_HYPER) { col = 0xB85A20; }
        var fontBg = Gfx.FONT_NUMBER_MEDIUM;
        var bgH = dc.getFontHeight(fontBg);
        if (bgH > 88) {
            fontBg = Gfx.FONT_NUMBER_MILD;
            bgH = dc.getFontHeight(fontBg);
        }
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, y, fontBg, sgvText, Gfx.TEXT_JUSTIFY_LEFT);
        var tw = dc.getTextWidthInPixels(sgvText, fontBg);
        var ah = 22;
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            dc.drawScaledBitmap(pad + tw + 6, y + ((bgH - ah) / 2).toNumber(), ah, ah, bmp);
        }
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, y + bgH - 2, Gfx.FONT_XTINY, "mg/dL", Gfx.TEXT_JUSTIFY_LEFT);
        return bgH + 10;
    }

    //! Footer synthesis line: IOB | TBR | Δ | TIR
    function drawFooter(dc, pad, y, w, iob, basal, deltaNum, tir) {
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad, y, pad + w, y);
        var cy = y + 6;
        var iobV = "--";
        if (iob != null && iob.equals("") == false) { iobV = iob.toString(); }
        var tbrV = "--";
        if (basal != null && basal.equals("") == false && basal.equals("-- %") == false) {
            tbrV = basal.toString();
        }
        var dStr = "Δ --";
        if (deltaNum != null) {
            dStr = deltaNum > 0 ? ("Δ +" + deltaNum.toString()) : ("Δ " + deltaNum.toString());
        }
        var tirV = "--";
        if (tir != null) { tirV = "TIR " + tir.toString() + "%"; }
        var line = "IOB " + iobV + " | TBR " + tbrV + " | " + dStr + " | " + tirV;
        dc.setColor(COL_LABEL, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, cy, Gfx.FONT_XTINY, line, Gfx.TEXT_JUSTIFY_LEFT);
    }

    function drawPredictHint(dc, cx, y, predict15, state) {
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        if (predict15 == null) { return; }
        dc.setColor(COL_PENCIL_ALERT, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, "→ " + predict15.toString() + " in 15m", Gfx.TEXT_JUSTIFY_CENTER);
    }

}
