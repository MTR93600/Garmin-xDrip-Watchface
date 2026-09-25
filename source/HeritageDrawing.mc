using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;
using Toybox.Lang as Lang;
using Toybox.Math as Math;

//! CONCEPT C — Heritage drawing helpers (central unicorn + halo + moons).
module HeritageDrawing {

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
        var band = 56;
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

    //! Map SGV + trend arrow name → unicorn drawable.
    function unicornDrawable(sgv, auswahlPfeil) {
        if (sgv != null && sgv < 70) {
            return Ui.loadResource(Rez.Drawables.unicorn_hypo);
        }
        if (sgv != null && sgv >= 250) {
            return Ui.loadResource(Rez.Drawables.unicorn_hyper);
        }
        if (auswahlPfeil != null) {
            if (auswahlPfeil.equals("DoubleUp")) {
                return Ui.loadResource(Rez.Drawables.unicorn_double_up);
            }
            if (auswahlPfeil.equals("DoubleDown")) {
                return Ui.loadResource(Rez.Drawables.unicorn_double_down);
            }
        }
        return Ui.loadResource(Rez.Drawables.unicorn_normal);
    }

    function drawUnicornByState(dc, cx, cy, size, sgv, auswahlPfeil) {
        var bmp = unicornDrawable(sgv, auswahlPfeil);
        if (bmp == null) { return; }
        var bw = bmp.getWidth();
        var bh = bmp.getHeight();
        if (bw < 1 || bh < 1) { return; }
        var scale = size.toFloat() / (bw > bh ? bw : bh).toFloat();
        var dw = (bw * scale).toNumber();
        var dh = (bh * scale).toNumber();
        if (dw < 1) { dw = 1; }
        if (dh < 1) { dh = 1; }
        dc.drawScaledBitmap(cx - dw / 2, cy - dh / 2, dw, dh, bmp);
    }

    function drawHaloRing(dc, cx, cy, radius, tir, state) {
        var col = 0x00E676;
        if (state == STATE_HYPO) { col = 0xFF3D57; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { col = 0xFF8C00; }

        var gapStart = 225;
        var gapEnd = 315;
        var sweep = 270;
        var tirA = ((tir.toFloat() / 100.0) * sweep).toNumber();
        if (tirA > sweep) { tirA = sweep; }

        dc.setPenWidth(8);
        dc.setColor(0x222222, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, gapStart, gapEnd);
        if (tirA > 2) {
            var fillEnd = gapStart - tirA;
            while (fillEnd < 0) { fillEnd += 360; }
            dc.setColor(col, Gfx.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, gapStart, fillEnd);
        }

        if (state == STATE_HYPO) {
            dc.setPenWidth(2);
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
            for (var i = 0; i < 12; i++) {
                var a = gapStart - ((i.toFloat() / 11.0) * sweep).toNumber();
                while (a < 0) { a += 360; }
                var rad = a * Math.PI / 180.0;
                var x1 = cx + (radius - 6) * Math.cos(rad);
                var y1 = cy - (radius - 6) * Math.sin(rad);
                var x2 = cx + (radius + 4) * Math.cos(rad);
                var y2 = cy - (radius + 4) * Math.sin(rad);
                dc.drawLine(x1.toNumber(), y1.toNumber(), x2.toNumber(), y2.toNumber());
            }
        }
    }

    //! IOB left / TBR right — in the open bottom of the halo (keeps TBR on-screen).
    function drawSideMetrics(dc, cx, cy, radius, iob, tbr, state) {
        var font = Gfx.FONT_XTINY;
        var y = cy + (radius * 0.82).toNumber();
        var xOff = (radius * 0.72).toNumber();
        if (xOff < 56) { xOff = 56; }
        var col = 0xCCCCCC;
        if (state == STATE_HYPO || state == STATE_HYPER) {
            col = 0xFFFFFF;
        }
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        var iobStr = "--";
        if (iob != null && iob.equals("") == false && iob.equals("--") == false) {
            iobStr = iob;
        }
        var tbrStr = "--";
        if (tbr != null && tbr.equals("") == false && tbr.equals("--") == false && tbr.equals("-- %") == false) {
            tbrStr = tbr;
        }
        // Truncate long TBR so it stays inside the bezel
        if (tbrStr.length() > 8) {
            tbrStr = tbrStr.substring(0, 8);
        }
        dc.drawText(cx - xOff, y, font, iobStr, Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + xOff, y, font, tbrStr, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function drawOrbitingMoons(dc, cx, cy, radius, iob, tbr, tir, state) {
        // Kept for API compatibility — prefer drawSideMetrics.
        drawSideMetrics(dc, cx, cy, radius, iob, tbr, state);
    }

    function drawGlucoseSmallTop(dc, cx, y, sgvText, auswahlPfeil, state) {
        var col = 0x2C8EFF;
        if (state == STATE_HYPO || state == STATE_HYPER) { col = 0xFFFFFF; }
        var font = Gfx.FONT_NUMBER_MEDIUM;
        var th = dc.getFontHeight(font);
        if (th > 56) {
            font = Gfx.FONT_NUMBER_MILD;
            th = dc.getFontHeight(font);
        }
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, sgvText, Gfx.TEXT_JUSTIFY_CENTER);

        // Code-drawn arrow centered under SGV (classic Flat bitmap reads as a dash)
        var arrowMidY = y + th + 12;
        drawCenteredTrendArrow(dc, cx, arrowMidY, auswahlPfeil, col);

        if (state == STATE_HYPO) {
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, arrowMidY + 16, Gfx.FONT_XTINY, "LOW", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (state == STATE_HYPER) {
            dc.setColor(0xFF8C00, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, arrowMidY + 16, Gfx.FONT_XTINY, "HIGH", Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Visible trend arrow centered on cx (tip points per direction).
    function drawCenteredTrendArrow(dc, cx, midY, auswahlPfeil, col) {
        if (auswahlPfeil == null) { return; }
        var s = 11;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(3);

        if (auswahlPfeil.equals("Flat")) {
            var x0 = cx - s - 4;
            var x1 = cx + s + 2;
            dc.drawLine(x0, midY, x1 - 4, midY);
            dc.fillPolygon([[x1, midY], [x1 - s, midY - s / 2 - 1], [x1 - s, midY + s / 2 + 1]]);
            return;
        }
        if (auswahlPfeil.equals("SingleUp") || auswahlPfeil.equals("DoubleUp")) {
            dc.drawLine(cx, midY + s, cx, midY - s + 2);
            dc.fillPolygon([[cx, midY - s], [cx - s / 2 - 2, midY - 1], [cx + s / 2 + 2, midY - 1]]);
            if (auswahlPfeil.equals("DoubleUp")) {
                dc.fillPolygon([[cx, midY + 2], [cx - s / 2 - 2, midY + s - 1], [cx + s / 2 + 2, midY + s - 1]]);
            }
            return;
        }
        if (auswahlPfeil.equals("SingleDown") || auswahlPfeil.equals("DoubleDown")) {
            dc.drawLine(cx, midY - s, cx, midY + s - 2);
            dc.fillPolygon([[cx, midY + s], [cx - s / 2 - 2, midY + 1], [cx + s / 2 + 2, midY + 1]]);
            if (auswahlPfeil.equals("DoubleDown")) {
                dc.fillPolygon([[cx, midY - 2], [cx - s / 2 - 2, midY - s + 1], [cx + s / 2 + 2, midY - s + 1]]);
            }
            return;
        }
        if (auswahlPfeil.equals("FortyFiveUp")) {
            dc.drawLine(cx - s, midY + s / 2, cx + s - 2, midY - s / 2);
            dc.fillPolygon([[cx + s, midY - s / 2], [cx + 1, midY - s / 2 - 2], [cx + s - 2, midY + s / 2]]);
            return;
        }
        if (auswahlPfeil.equals("FortyFiveDown")) {
            dc.drawLine(cx - s, midY - s / 2, cx + s - 2, midY + s / 2);
            dc.fillPolygon([[cx + s, midY + s / 2], [cx + 1, midY + s / 2 + 2], [cx + s - 2, midY - s / 2]]);
        }
    }

    function drawSmileSparkline(dc, x, y, w, h, graph, state) {
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
        var col = 0x2C8EFF;
        if (state == STATE_HYPO) { col = 0xFF8C8C; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { col = 0xFFCC88; }

        // Soft fill
        dc.setColor(state == STATE_NORMAL ? 0x112233 : 0x222222, Gfx.COLOR_TRANSPARENT);
        for (var i = 0; i < graph.size() - 1; i++) {
            var px1 = x + ((i.toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var n1 = (graph[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py1 = y + h - (n1 * h).toNumber();
            var px2 = x + (((i + 1).toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var n2 = (graph[i + 1] - gmin).toFloat() / (gmax - gmin).toFloat();
            var py2 = y + h - (n2 * h).toNumber();
            dc.fillPolygon([[px1, py1], [px2, py2], [px2, y + h], [px1, y + h]]);
        }

        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var i = 0; i < graph.size() - 1; i++) {
            var ax = x + ((i.toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var an = (graph[i] - gmin).toFloat() / (gmax - gmin).toFloat();
            var ay = y + h - (an * h).toNumber();
            var bx = x + (((i + 1).toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var bn = (graph[i + 1] - gmin).toFloat() / (gmax - gmin).toFloat();
            var by = y + h - (bn * h).toNumber();
            dc.drawLine(ax, ay, bx, by);
        }
    }

    function drawBottomPill(dc, state) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bh = 28;
        var bw = 160;
        var by = h - bh - 14;
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
        dc.setColor(bg, bg);
        dc.fillRoundedRectangle(bx, by, bw, bh, 14);
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, by + bh / 2, Gfx.FONT_XTINY, txt, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        return by;
    }

}
