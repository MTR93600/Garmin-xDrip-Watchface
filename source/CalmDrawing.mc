using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

//! Calm Loop drawing helpers — thin ring, vignette edges, minimal chrome.
module CalmDrawing {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;   // visual NORMAL in Calm
    const STATE_HYPER = 3;

    function drawVignetteBackground(dc, state) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(0x000000, 0x000000);
        dc.fillRectangle(0, 0, w, h);
        if (state != STATE_HYPO && state != STATE_HYPER) {
            return;
        }
        var topC = state == STATE_HYPO ? 0x330000 : 0x332000;
        var band = 80;
        if (band > h / 4) { band = h / 4; }
        // Top vignette
        for (var y = 0; y < band; y++) {
            var ratio = (band - y).toFloat() / band.toFloat();
            var col = mixTowardBlack(topC, ratio * 0.55);
            dc.setColor(col, col);
            dc.drawLine(0, y, w, y);
        }
        // Bottom vignette
        for (var y = h - band; y < h; y++) {
            var ratio2 = (y - (h - band)).toFloat() / band.toFloat();
            var col2 = mixTowardBlack(topC, ratio2 * 0.55);
            dc.setColor(col2, col2);
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
        var nr = (r * f).toNumber();
        var ng = (g * f).toNumber();
        var nb = (b * f).toNumber();
        return (nr << 16) | (ng << 8) | nb;
    }

    function drawThinTirRing(dc, cx, cy, radius, tir, state) {
        var showProp = App.getApp().getProperty("showTirRing");
        var show = showProp == null || showProp.toNumber() != 0;
        if (!show) { return; }

        var col = 0x00E676;
        if (state == STATE_HYPO) { col = 0xFF3D57; }
        else if (state == STATE_HYPER) { col = 0xFF8C00; }

        var gapStart = 225;
        var gapEnd = 315;
        var sweep = 270;
        var tirA = ((tir.toFloat() / 100.0) * sweep).toNumber();
        if (tirA > sweep) { tirA = sweep; }

        dc.setPenWidth(2);
        dc.setColor(0x222222, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, gapStart, gapEnd);

        if (tirA > 2) {
            var fillEnd = gapStart - tirA;
            while (fillEnd < 0) { fillEnd += 360; }
            // Normal: dimmer green via darker mix
            if (state == STATE_NORMAL || state == STATE_HIGH) {
                dc.setColor(0x008C4A, Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(col, Gfx.COLOR_TRANSPARENT);
            }
            dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, gapStart, fillEnd);

            // End dot
            var a = fillEnd;
            var rad = a * Math.PI / 180.0;
            var dx = cx + radius * Math.cos(rad);
            var dy = cy - radius * Math.sin(rad);
            dc.setColor(col, Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(dx.toNumber(), dy.toNumber(), 2);
        }
    }

    function drawCalmSparkline(dc, x, y, w, h, graph, state) {
        if (graph == null || graph.size() < 2) { return; }
        var gmin = 500;
        var gmax = 0;
        for (var i = 0; i < graph.size(); i++) {
            if (graph[i] < gmin) { gmin = graph[i]; }
            if (graph[i] > gmax) { gmax = graph[i]; }
        }
        if (gmax - gmin < 40) {
            var mid = (gmax + gmin) / 2;
            gmin = mid - 20;
            gmax = mid + 20;
        }
        var lineC = 0x2C8EFF;
        var fillC = 0x112233;
        if (state == STATE_HYPO || state == STATE_HYPER) {
            lineC = 0xFFFFFF;
            fillC = 0x222222;
        }

        var pts = [];
        for (var i = 0; i < graph.size(); i++) {
            var px = x + ((i.toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var norm = (graph[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py = y + h - (norm * h).toNumber();
            pts.add([px, py]);
        }
        dc.setColor(fillC, Gfx.COLOR_TRANSPARENT);
        for (var i = 0; i < pts.size() - 1; i++) {
            dc.fillPolygon([
                [pts[i][0], pts[i][1]],
                [pts[i + 1][0], pts[i + 1][1]],
                [pts[i + 1][0], y + h],
                [pts[i][0], y + h]
            ]);
        }
        dc.setColor(lineC, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i < pts.size() - 1; i++) {
            dc.drawLine(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]);
        }
        dc.setColor(0x555555, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x, y + h + 1, Gfx.FONT_XTINY, "3h", Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + w, y + h + 1, Gfx.FONT_XTINY, "now", Gfx.TEXT_JUSTIFY_RIGHT);
    }

    function drawGlucoseCalm(dc, cx, cy, sgvText, auswahlPfeil, state) {
        var col = 0x2C8EFF;
        if (state == STATE_HYPO || state == STATE_HYPER) {
            col = 0xFFFFFF;
        }
        var fontBg = Gfx.FONT_NUMBER_HOT;
        var bgH = dc.getFontHeight(fontBg);
        if (bgH > 120) {
            fontBg = Gfx.FONT_NUMBER_MEDIUM;
            bgH = dc.getFontHeight(fontBg);
        }
        var bgY = cy - (bgH / 2).toNumber() - 8;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_CENTER);

        var unitY = bgY + bgH - 8;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx + (bgH / 3).toNumber() + 8, unitY - 4, Gfx.FONT_TINY, "mg/dL", Gfx.TEXT_JUSTIFY_LEFT);

        // Trend arrow under glucose (centered), not far right
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            var ah = 22;
            dc.drawScaledBitmap(cx - ah / 2, unitY + dc.getFontHeight(Gfx.FONT_TINY) + 2, ah, ah, bmp);
        }
    }

    function drawTopBarMinimal(dc, pad, datum, steps, heartrate, state) {
        var w = dc.getWidth();
        dc.setColor(0x888888, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, pad, Gfx.FONT_XTINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(w - pad, pad, Gfx.FONT_XTINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);

        // Tiny unicorn outline (center) — calm, no full bitmap
        var ux = w / 2;
        var uy = pad + 6;
        var alert = state == STATE_HYPO || state == STATE_HYPER;
        dc.setColor(alert ? 0xFFFFFF : 0x555555, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(ux, uy + 4, 5);
        dc.drawLine(ux, uy - 2, ux + 4, uy + 2); // horn
    }

    function drawBottomPill(dc, state, version) {
        if (state != STATE_HYPO && state != STATE_HYPER) { return; }
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bh = 28;
        var bw = 160;
        var by = h - bh - 12;
        if (by < h * 0.75) { by = ((h * 0.88)).toNumber(); }
        var bx = w / 2 - bw / 2;
        var bg = 0x4A0000;
        var fg = 0xFF8C8C;
        var txt = "HYPO · AAPS";
        if (state == STATE_HYPER) {
            bg = 0x5A2A00;
            fg = 0xFFCC88;
            txt = "HIGH · AAPS";
        }
        if (version != null && version.equals("") == false) {
            txt = txt + " " + version;
        }
        dc.setColor(bg, bg);
        dc.fillRoundedRectangle(bx, by, bw, bh, 14);
        dc.setColor(fg, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, by + bh / 2, Gfx.FONT_XTINY, txt, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

}
