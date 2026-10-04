using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as Sys;

//! CONCEPT — Atelier (layoutStyle=8).
//! Elegant horological dial: the 3h glucose curve + dotted +60m prediction
//! is watermarked (filigrane) behind slim analog hands. Alert states reuse
//! the Pilot visual language (vignette, ring color, white glucose, pill).
module AtelierDrawing {

    //! Title + steps/HR, centered near the top of the dial.
    function drawTitle(dc, cx, y, steps, heartrate) {
        dc.setColor(0xB08D57, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, "ATELIER", Gfx.TEXT_JUSTIFY_CENTER);
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.setColor(0x666666, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y + 20, Gfx.FONT_XTINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Thin TIR arc across the top of the dial (120° sweep over 12 o'clock).
    function drawTirArc(dc, cx, cy, r, tir, state) {
        var col = 0x00C853;
        if (state == PilotDrawing.STATE_HYPO) { col = 0xFF3D57; }
        else if (state == PilotDrawing.STATE_HYPER || state == PilotDrawing.STATE_HIGH) { col = 0xFF8C00; }
        var startA = 150;
        var endA = 30;
        var sweep = 120;
        dc.setPenWidth(4);
        dc.setColor(0x222222, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, r, Gfx.ARC_CLOCKWISE, startA, endA);
        var t = tir;
        if (t == null) { t = 0; }
        if (t < 0) { t = 0; }
        if (t > 100) { t = 100; }
        var fill = ((t.toFloat() / 100.0) * sweep).toNumber();
        if (fill > 2) {
            var fillEnd = startA - fill;
            while (fillEnd < 0) { fillEnd += 360; }
            dc.setColor(col, Gfx.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Gfx.ARC_CLOCKWISE, startA, fillEnd);
        }
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - r + 8, Gfx.FONT_XTINY, t.toString() + "% TIR", Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Filigrane: 3h glucose curve + dotted +60m prediction, very discreet.
    //! No alpha blending (not supported everywhere) — faint slate tones instead.
    function drawFiligraneGraph(dc, x, y, w, h, past, future) {
        if (past == null || past.size() < 2) { return; }
        var gmin = 500;
        var gmax = 0;
        var i = 0;
        for (i = 0; i < past.size(); i++) {
            if (past[i] < gmin) { gmin = past[i]; }
            if (past[i] > gmax) { gmax = past[i]; }
        }
        if (future != null) {
            for (i = 0; i < future.size(); i++) {
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
        var pastPts = [];
        for (i = 0; i < past.size(); i++) {
            var px = x + ((i.toFloat() / (past.size() - 1).toFloat()) * pastW).toNumber();
            var norm = (past[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py = y + h - (norm * h).toNumber();
            pastPts.add([px, py]);
        }
        var futPts = [];
        if (future != null && future.size() >= 2) {
            for (i = 0; i < future.size(); i++) {
                var px2 = x + pastW + ((i.toFloat() / (future.size() - 1).toFloat()) * (w - pastW)).toNumber();
                var norm2 = (future[i] - gmin).toFloat() / (gmax - gmin).toFloat();
                var py2 = y + h - (norm2 * h).toNumber();
                futPts.add([px2, py2]);
            }
        }
        dc.setColor(0x1E2C3E, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (i = 0; i < pastPts.size() - 1; i++) {
            dc.drawLine(pastPts[i][0], pastPts[i][1], pastPts[i + 1][0], pastPts[i + 1][1]);
        }
        dc.setColor(0x2E3C4E, Gfx.COLOR_TRANSPARENT);
        if (futPts.size() >= 2) {
            if (pastPts.size() > 0) {
                dc.drawLine(pastPts[pastPts.size() - 1][0], pastPts[pastPts.size() - 1][1], futPts[0][0], futPts[0][1]);
            }
            for (i = 0; i < futPts.size() - 1; i++) {
                if ((i % 2) == 0) {
                    dc.drawLine(futPts[i][0], futPts[i][1], futPts[i + 1][0], futPts[i + 1][1]);
                }
            }
        }
    }

    //! Slim white analog hands from the dial center + center dot.
    function drawHands(dc, cx, cy) {
        var t = Sys.getClockTime();
        var hour = t.hour % 12;
        var min = t.min;
        var mRad = (90 - min * 6) * Math.PI / 180.0;
        var hRad = (90 - hour * 30 - min * 0.5) * Math.PI / 180.0;
        var mx = (cx + 138 * Math.cos(mRad)).toNumber();
        var my = (cy - 138 * Math.sin(mRad)).toNumber();
        var hx = (cx + 92 * Math.cos(hRad)).toNumber();
        var hy = (cy - 92 * Math.sin(hRad)).toNumber();
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(5);
        dc.drawLine(cx, cy, hx, hy);
        dc.setPenWidth(4);
        dc.drawLine(cx, cy, mx, my);
        dc.setColor(0xFFFFFF, 0xFFFFFF);
        dc.fillCircle(cx, cy, 7);
        dc.setColor(0x000000, 0x000000);
        dc.fillCircle(cx, cy, 3);
    }

    //! Thin concentric dial rings (guilloche hint).
    function drawDialRings(dc, cx, cy, r) {
        dc.setColor(0x1A1A1A, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, r);
        dc.drawCircle(cx, cy, r - 14);
    }

    //! Date window at 3 o'clock + amber mode chip (hidden when no mode).
    function drawDateWindow(dc, x, y, w, h, datum, mode) {
        dc.setColor(0x333333, 0x333333);
        dc.fillRoundedRectangle(x, y, w, h, 6);
        dc.setColor(0x0D0D0D, 0x0D0D0D);
        dc.fillRoundedRectangle(x + 1, y + 1, w - 2, h - 2, 5);
        if (datum != null) {
            dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
            dc.drawText(x + w / 2, y + h / 2, Gfx.FONT_TINY, datum,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
        var showMode = mode != null && !mode.equals("");
        if (showMode) {
            var chipTxt = mode.toString();
            var cw = dc.getTextWidthInPixels(chipTxt, Gfx.FONT_XTINY) + 18;
            var ch = 24;
            var cX = x + w + 8;
            var cY = y + ((h - ch) / 2).toNumber();
            if (cX + cw > dc.getWidth() - 16) {
                // Fallback: chip below the window, centered
                cX = x + ((w - cw) / 2).toNumber();
                if (cX < 16) { cX = 16; }
                cY = y + h + 6;
            }
            dc.setColor(0x5A3A00, 0x5A3A00);
            dc.fillRoundedRectangle(cX, cY, cw, ch, 12);
            dc.setColor(0xFFC266, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cX + cw / 2, cY + ch / 2, Gfx.FONT_XTINY, chipTxt,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Big glucose readout at 6 o'clock with trend arrow (pilot language).
    function drawGlucoseAtelier(dc, cx, cyCenter, sgvText, auswahlPfeil, state) {
        var col = 0x2C8EFF;
        if (state == PilotDrawing.STATE_HYPO || state == PilotDrawing.STATE_HYPER) { col = 0xFFFFFF; }
        var fontBg = Gfx.FONT_NUMBER_MEDIUM;
        var bgH = dc.getFontHeight(fontBg);
        var bgY = cyCenter - (bgH / 2).toNumber() - 2;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_CENTER);
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            var tw = dc.getTextWidthInPixels(sgvText, fontBg);
            var ax = cx + (tw / 2).toNumber() + 8;
            dc.drawScaledBitmap(ax, bgY + 2, 24, 24, bmp);
        }
        if (state == PilotDrawing.STATE_HYPO) {
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 16, Gfx.FONT_XTINY, "LOW · <70", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (state == PilotDrawing.STATE_HYPER) {
            dc.setColor(0xFF8C00, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, bgY - 16, Gfx.FONT_XTINY, "HIGH GLUCOSE", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    //! "TBR 120% · 45 min · TGT 100" — parts omitted when data missing.
    function drawTherapyLine(dc, cx, y, anzeigeBasal, anzeigeTbrMins, anzeigeTarget) {
        var parts = "";
        if (anzeigeBasal != null && !anzeigeBasal.equals("") && !anzeigeBasal.equals("-- %")) {
            parts = "TBR " + anzeigeBasal;
            if (anzeigeTbrMins != null && !anzeigeTbrMins.equals("")) {
                parts = parts + " · " + anzeigeTbrMins + " min";
            }
        }
        if (anzeigeTarget != null && !anzeigeTarget.equals("")) {
            if (!parts.equals("")) { parts = parts + " · "; }
            parts = parts + "TGT " + anzeigeTarget;
        }
        if (parts.equals("")) { return; }
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Gfx.FONT_XTINY, parts, Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Small circular sub-dial with centered label.
    function drawSubDial(dc, cx, cy, r, text) {
        dc.setColor(0x2A2A2A, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, r);
        if (text != null) {
            dc.setColor(0xCCCCCC, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Gfx.FONT_XTINY, text,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

}
