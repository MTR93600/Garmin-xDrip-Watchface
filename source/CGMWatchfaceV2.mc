using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.System as Sys;

//! V2 color-aware layout (layoutStyle=3) — adaptive for round + rectangular.
module CGMWatchfaceV2 {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HIGH = 2;
    const STATE_HYPER = 3;
    const STATE_NONE = 4;

    //! Horizontal inset so text stays inside a round bezel at row y.
    function edgeInsetX(y, width, height, isRound) {
        if (isRound == false) {
            return width >= 360 ? 14 : 10;
        }
        var r = width / 2.0;
        var cy = height / 2.0;
        var dy = y.toFloat() - cy;
        var inside = r * r - dy * dy;
        if (inside <= 0) {
            return (width * 0.22).toNumber();
        }
        var halfChord = Math.sqrt(inside);
        var inset = (width / 2.0 - halfChord).toNumber() + 8;
        if (inset < 18) { inset = 18; }
        return inset;
    }

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
        auswahlPfeil
    ) {
        AimicoDraw.hideClassicLabels(view);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var settings = Sys.getDeviceSettings();
        var isRound = false;
        if (settings has :screenShape) {
            isRound = settings.screenShape == Sys.SCREEN_SHAPE_ROUND;
        }

        var pad = width >= 360 ? 14 : 10;
        if (isRound) { pad = (width * 0.08).toNumber(); }
        if (pad < 16) { pad = 16; }

        var hyperProp = App.getApp().getProperty("hyperThreshold");
        var hyper = hyperProp != null ? hyperProp.toNumber() : 250;
        if (hyper == null) { hyper = 250; }

        var showTirProp = App.getApp().getProperty("showTirRing");
        var showTir = showTirProp == null || showTirProp.toNumber() != 0;

        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"].toNumber();
        }
        var state = stateFromSgv(sgvMgdl, zielbereichLow, zielbereichHigh, hyper);
        var graph = buildGraph(punkte);
        var tir = calcTir(graph, zielbereichLow, zielbereichHigh);
        var ageMin = sanitizeAge(verzoegerung);

        // Footer — more bottom inset on round bezels
        var timeFont = Gfx.FONT_SMALL;
        var timeH = dc.getFontHeight(timeFont);
        var bottomPad = isRound ? pad + 10 : pad;
        var timeY = height - bottomPad - timeH;
        var techFont = Gfx.FONT_TINY;
        var techH = dc.getFontHeight(techFont);
        var techY = timeY - techH - (isRound ? 6 : 4);
        var headerH = dc.getFontHeight(Gfx.FONT_TINY) + 6;
        var labFont = Gfx.FONT_XTINY;
        var labH = dc.getFontHeight(labFont) + 2;
        var topPad = isRound ? pad + 4 : pad;

        var midTop = topPad + headerH;
        var midBottom = techY - labH - 2;
        var midH = midBottom - midTop;
        if (midH < 120) { midH = 120; }

        // Ring — slightly smaller on round to leave side room for unicorn/arrow
        var ringFrac = isRound ? 0.28 : 0.34;
        var ringBudget = ((midH * (isRound ? 62 : 70)) / 100).toNumber();
        var ringR = ((width < height ? width : height) * ringFrac).toNumber();
        var maxR = (ringBudget / 2) - 2;
        if (maxR < 58) { maxR = 58; }
        if (ringR > maxR) { ringR = maxR; }
        var gluCy = midTop + ringR;
        var ringBottom = gluCy + ringR;

        var sparkY = ringBottom + (isRound ? 6 : 8);
        var sparkH = midBottom - sparkY;
        if (sparkH < 28) { sparkH = 28; }
        if (sparkH > 56) { sparkH = 56; }
        if (sparkY + sparkH + labH > techY) {
            sparkH = techY - labH - sparkY;
            if (sparkH < 24) {
                sparkH = 24;
                var overflow = (sparkY + sparkH + labH) - techY;
                if (overflow > 0 && ringR > 58) {
                    ringR = ringR - (overflow / 2) - 2;
                    if (ringR < 58) { ringR = 58; }
                    gluCy = midTop + ringR;
                    ringBottom = gluCy + ringR;
                    sparkY = ringBottom + 6;
                    sparkH = techY - labH - sparkY;
                    if (sparkH < 24) { sparkH = 24; }
                }
            }
        }

        drawBackground(dc, width, height, state);

        // Header — use chord insets so corners aren't clipped on round
        var headInset = edgeInsetX(topPad + 4, width, height, isRound);
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(headInset, topPad, Gfx.FONT_TINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(width - headInset, topPad, Gfx.FONT_TINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);
        if (state == STATE_HYPO || state == STATE_HIGH || state == STATE_HYPER) {
            dc.setColor(0xFFCC00, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, topPad, Gfx.FONT_TINY, "!", Gfx.TEXT_JUSTIFY_CENTER);
        }

        // Unicorn LEFT of ring — round: larger + closer to ring (not stuck on bezel)
        if (AimicoDraw.shouldShowMascot(isHighPower) && state != STATE_NONE) {
            var kind = AimicoState.mascotKind(sgvMgdl, zielbereichLow, zielbereichHigh);
            var bmp = AimicoState.mascotDrawable(kind);
            if (bmp != null) {
                var sideInset = edgeInsetX(gluCy, width, height, isRound);
                var mh;
                if (isRound) {
                    mh = (ringR * 1.15).toNumber();
                    if (mh < 70) { mh = 70; }
                    if (mh > 120) { mh = 120; }
                } else {
                    mh = (ringR * 1.18).toNumber();
                    if (mh < 72) { mh = 72; }
                    if (mh > 140) { mh = 140; }
                }
                // Prefer flush against the ring (X1 look); only clamp to bezel if needed
                var mx = cx - ringR - mh - (isRound ? 2 : 4);
                if (mx < sideInset) {
                    // Not enough chord: shrink slightly so it still sits near the ring
                    mh = cx - ringR - sideInset - (isRound ? 2 : 4);
                    if (mh < (isRound ? 56 : 52)) { mh = isRound ? 56 : 52; }
                    mx = cx - ringR - mh - (isRound ? 2 : 4);
                    if (mx < sideInset) { mx = sideInset; }
                }
                var my = gluCy - (mh / 2).toNumber();
                AimicoDraw.drawMascotScaled(dc, bmp, mx, my, mh, mh);
            }
        }

        // Trend arrow — centered in right free space, chord-aware
        var ah = isRound ? 28 : 34;
        if (ah > ringR * 0.50) { ah = (ringR * 0.50).toNumber(); }
        if (ah < 22) { ah = 22; }
        var arrowBmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (arrowBmp != null) {
            var rightInset = edgeInsetX(gluCy, width, height, isRound);
            var rightGapLeft = cx + ringR + 2;
            var rightGapRight = width - rightInset;
            var gapW = rightGapRight - rightGapLeft;
            if (ah > gapW - 2 && gapW > 18) { ah = gapW - 2; }
            var arrowX = rightGapLeft + ((gapW - ah) / 2).toNumber();
            if (arrowX < rightGapLeft) { arrowX = rightGapLeft; }
            if (arrowX + ah > rightGapRight) { arrowX = rightGapRight - ah; }
            dc.drawScaledBitmap(arrowX, gluCy - ah / 2, ah, ah, arrowBmp);
        }

        // Sparkline — inset for round
        var sparkInset = edgeInsetX(sparkY + sparkH / 2, width, height, isRound);
        if (graph != null && graph.size() >= 2 && sparkH >= 24) {
            drawSparkline(dc, sparkInset, sparkY, width - sparkInset * 2, sparkH, graph, state);
            var labY = sparkY + sparkH;
            var labInset = edgeInsetX(labY, width, height, isRound);
            dc.setColor(0x777777, Gfx.COLOR_TRANSPARENT);
            dc.drawText(labInset, labY, labFont, "3h", Gfx.TEXT_JUSTIFY_LEFT);
            dc.drawText(width - labInset, labY, labFont, "now", Gfx.TEXT_JUSTIFY_RIGHT);
        }

        // TIR ring
        if (showTir && state != STATE_NONE) {
            drawTirRing(dc, cx, gluCy, ringR, tir, state);
        }

        // Inside ring: small delta above SGV
        var fontBg = Gfx.FONT_NUMBER_MILD;
        var bgH = dc.getFontHeight(fontBg);
        if (bgH > ringR - 14) {
            fontBg = Gfx.FONT_MEDIUM;
            bgH = dc.getFontHeight(fontBg);
        }
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }
        var gluCol = 0x2C8EFF;
        if (state == STATE_HYPO || state == STATE_HIGH || state == STATE_HYPER) {
            gluCol = 0xFFFFFF;
        }

        var tinyH = dc.getFontHeight(Gfx.FONT_TINY);
        var deltaH = dc.getFontHeight(labFont);
        var bgY = gluCy - (bgH / 2).toNumber() - 2;

        var deltaStr = "";
        if (anzeigeDelta != null && anzeigeDelta.equals("") == false && anzeigeDelta.equals("--") == false) {
            deltaStr = anzeigeDelta;
        }
        if (deltaStr.equals("") == false) {
            var deltaY = bgY - deltaH - 2;
            if (deltaY > gluCy - ringR + 2) {
                dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
                dc.drawText(cx, deltaY, labFont, deltaStr, Gfx.TEXT_JUSTIFY_CENTER);
            }
        }

        dc.setColor(gluCol, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_CENTER);

        var unitY = bgY + bgH - 6;
        if (unitY + tinyH < ringBottom - 2) {
            dc.setColor(state == STATE_NORMAL ? 0x2C8EFF : 0xCCCCCC, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, unitY, Gfx.FONT_TINY, "mg/dL", Gfx.TEXT_JUSTIFY_CENTER);

            var statusY = unitY + tinyH;
            if (statusY + tinyH < ringBottom) {
                var ringStatus = "";
                if (state == STATE_HYPO) {
                    ringStatus = "LOW · TIR " + tir.toString() + "%";
                    dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
                } else if (state == STATE_HYPER || state == STATE_HIGH) {
                    ringStatus = "HIGH · TIR " + tir.toString() + "%";
                    dc.setColor(0xFF8C00, Gfx.COLOR_TRANSPARENT);
                } else if (state == STATE_NORMAL) {
                    ringStatus = tir.toString() + "% TIR";
                    dc.setColor(0x00E676, Gfx.COLOR_TRANSPARENT);
                }
                if (ringStatus.equals("") == false) {
                    dc.drawText(cx, statusY, Gfx.FONT_TINY, ringStatus, Gfx.TEXT_JUSTIFY_CENTER);
                }
            }
        }

        // Tech strip — clip width to chord on round
        var tech = buildTechLine(state, tir, anzeigeIOB, anzeigeBasal, anzeigeCOB, ageMin);
        var techInset = edgeInsetX(techY + techH / 2, width, height, isRound);
        var maxTechW = width - techInset * 2;
        while (dc.getTextWidthInPixels(tech, techFont) > maxTechW && tech.length() > 8) {
            tech = tech.substring(0, tech.length() - 2);
        }
        dc.setColor(0xCCCCCC, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, techY, techFont, tech, Gfx.TEXT_JUSTIFY_CENTER);

        // Time
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        dc.drawText(cx, timeY, timeFont, timeString, Gfx.TEXT_JUSTIFY_CENTER);

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, techY - techH, Gfx.FONT_TINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
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

    function drawDeltaCompact(dc, cx, rowY, ageMin, anzeigeDelta, auswahlPfeil) {
        var font = Gfx.FONT_SMALL;
        var parts = "";
        if (ageMin != null) {
            parts = ageMin.toString() + " m";
        }
        var deltaStr = "";
        if (anzeigeDelta != null && anzeigeDelta.equals("") == false && anzeigeDelta.equals("--") == false) {
            deltaStr = anzeigeDelta;
        }
        if (parts.equals("") == false && deltaStr.equals("") == false) {
            parts = parts + "  " + deltaStr;
        } else if (deltaStr.equals("") == false) {
            parts = deltaStr;
        }
        dc.setColor(0xFFFFFF, Gfx.COLOR_TRANSPARENT);
        if (parts.equals("") == false) {
            dc.drawText(cx - 8, rowY, font, parts, Gfx.TEXT_JUSTIFY_RIGHT);
        }
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp != null) {
            var ah = 22;
            dc.drawScaledBitmap(cx + 4, rowY + 1, ah, ah, bmp);
        }
    }

    function buildTechLine(state, tir, iob, basal, cob, ageMin) {
        // TIR lives in the ring; tech strip = loop numbers + age
        if (state == STATE_NONE) {
            return "No BG yet";
        }
        var tech = "";
        if (iob != null && iob.equals("") == false && iob.equals("--") == false) {
            tech = iob;
        }
        if (basal != null && basal.equals("") == false && basal.equals("--") == false && basal.equals("-- %") == false) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + basal;
        }
        if (cob != null && cob.equals("") == false && cob.equals("--") == false && cob.equals("-- g") == false) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + cob;
        }
        if (ageMin != null) {
            if (tech.equals("") == false) { tech = tech + " · "; }
            tech = tech + ageMin.toString() + "m";
        }
        if (tech.equals("")) {
            tech = tir.toString() + "% TIR";
        }
        return tech;
    }

    function drawArrowOnly(dc, cx, rowY, auswahlPfeil) {
        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        if (bmp == null) { return; }
        var ah = 18;
        dc.drawScaledBitmap(cx - ah / 2, rowY, ah, ah, bmp);
    }

    function stateFromSgv(sgv, low, high, hyper) {
        if (sgv == null) { return STATE_NONE; }
        var v = sgv.toNumber();
        if (v == null || v < 20 || v > 600) { return STATE_NONE; }
        var lo = low != null ? low.toNumber() : 70;
        var hi = high != null ? high.toNumber() : 180;
        var hy = hyper != null ? hyper.toNumber() : 250;
        if (lo == null) { lo = 70; }
        if (hi == null) { hi = 180; }
        if (hy == null) { hy = 250; }
        if (v < lo) { return STATE_HYPO; }
        if (v >= hy) { return STATE_HYPER; }
        if (v > hi) { return STATE_HIGH; }
        return STATE_NORMAL;
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

    function drawBackground(dc, w, h, state) {
        var top = 0x000000;
        var bottom = 0x000000;
        if (state == STATE_HYPO) {
            top = 0x4A0000;
            bottom = 0x1A0000;
        } else if (state == STATE_HYPER || state == STATE_HIGH) {
            top = 0x5A2500;
            bottom = 0x1F0F00;
        }
        if (top == bottom) {
            dc.setColor(top, top);
            dc.fillRectangle(0, 0, w, h);
            return;
        }
        for (var y = 0; y < h; y += 2) {
            var r = y.toFloat() / h.toFloat();
            var tr = (top >> 16) & 0xFF;
            var tg = (top >> 8) & 0xFF;
            var tb = top & 0xFF;
            var br = (bottom >> 16) & 0xFF;
            var bg = (bottom >> 8) & 0xFF;
            var bb = bottom & 0xFF;
            var cr = (tr * (1 - r) + br * r).toNumber();
            var cg = (tg * (1 - r) + bg * r).toNumber();
            var cb = (tb * (1 - r) + bb * r).toNumber();
            var col = (cr << 16) | (cg << 8) | cb;
            dc.setColor(col, col);
            dc.drawLine(0, y, w, y);
            if (y + 1 < h) {
                dc.drawLine(0, y + 1, w, y + 1);
            }
        }
    }

    function drawTirRing(dc, cx, cy, radius, tir, state) {
        // 270° horseshoe open at bottom. CIQ ARC_CLOCKWISE from 225→315 = 270° via top.
        var gapStart = 225;
        var gapEnd = 315;
        var sweep = 270;
        var tirA = ((tir.toFloat() / 100.0) * sweep).toNumber();
        if (tirA > sweep) { tirA = sweep; }
        var col = 0x00E676;
        if (state == STATE_HYPO) { col = 0xFF3D57; }
        else if (state == STATE_HYPER || state == STATE_HIGH) { col = 0xFF8C00; }

        var pen = radius >= 100 ? 10 : 8;
        dc.setPenWidth(pen);
        dc.setColor(0x333333, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, gapStart, gapEnd);

        if (tirA > 2) {
            // Clockwise from gapStart by tirA degrees → end angle
            var fillEnd = gapStart - tirA;
            while (fillEnd < 0) { fillEnd += 360; }
            dc.setColor(col, Gfx.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Gfx.ARC_CLOCKWISE, gapStart, fillEnd);
        }

        // HYPO: tick marks like mockup
        if (state == STATE_HYPO) {
            dc.setPenWidth(2);
            dc.setColor(0xFF3D57, Gfx.COLOR_TRANSPARENT);
            var ticks = 18;
            for (var i = 0; i < ticks; i++) {
                var a = gapStart - ((i.toFloat() / (ticks - 1).toFloat()) * sweep).toNumber();
                while (a < 0) { a += 360; }
                var rad = a * Math.PI / 180.0;
                // CIQ 0° = 3 o'clock, CCW positive → cos/sin standard
                var x1 = cx + (radius - 6) * Math.cos(rad);
                var y1 = cy - (radius - 6) * Math.sin(rad);
                var x2 = cx + (radius + 4) * Math.cos(rad);
                var y2 = cy - (radius + 4) * Math.sin(rad);
                dc.drawLine(x1.toNumber(), y1.toNumber(), x2.toNumber(), y2.toNumber());
            }
        }
    }

    function drawSparkline(dc, x, y, w, h, graph, state) {
        if (graph == null || graph.size() < 2) { return; }
        var gMin = 500;
        var gMax = 0;
        for (var i = 0; i < graph.size(); i++) {
            if (graph[i] < gMin) { gMin = graph[i]; }
            if (graph[i] > gMax) { gMax = graph[i]; }
        }
        if (gMax - gMin < 40) {
            var mid = (gMax + gMin) / 2;
            gMin = mid - 20;
            gMax = mid + 20;
        }
        var lineC = 0x2C8EFF;
        var fillC = 0x112233;
        if (state == STATE_HYPO) {
            lineC = 0xFFFFFF;
            fillC = 0x330000;
        } else if (state == STATE_HYPER || state == STATE_HIGH) {
            lineC = 0xFFFFFF;
            fillC = 0x331A00;
        }

        var pts = [];
        for (var i = 0; i < graph.size(); i++) {
            var px = x + ((i.toFloat() / (graph.size() - 1).toFloat()) * w).toNumber();
            var norm = (graph[i] - gMin).toFloat() / (gMax - gMin).toFloat();
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
        dc.setPenWidth(2);
        for (var i = 0; i < pts.size() - 1; i++) {
            dc.drawLine(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]);
        }
    }

}
