using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Lang as Lang;

//! AIMICO E1 layout drawer (opt-in via layoutStyle=1).
module CGMWatchfaceE1 {

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
        farbeZielbereich,
        farbeAlarm,
        BGFarbe,
        anzeigeSGV,
        anzeigeDelta,
        verzoegerung,
        anzeigeIOB,
        anzeigeBasal,
        anzeigeCOB,
        anzeigeFehler,
        auswahlPfeil
    ) {
        hideLabel(view, "TimeLabel");
        hideLabel(view, "DateLabel");
        hideLabel(view, "sgvLabel");
        hideLabel(view, "deltaLabel");
        hideLabel(view, "verzLabel");
        hideLabel(view, "iobLabel");
        hideLabel(view, "cobLabel");
        hideLabel(view, "basalLabel");

        var width = dc.getWidth();
        var height = dc.getHeight();
        var pad = width >= 360 ? 14 : 10;

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        var showMascotProp = App.getApp().getProperty("showMascot");
        var showMascotMode = showMascotProp != null ? showMascotProp.toNumber() : 1;
        var drawMascot = true;
        if (showMascotMode == 0) {
            drawMascot = false;
        } else if (showMascotMode == 2 && isHighPower == false) {
            drawMascot = false;
        }

        var sgvColor = Gfx.COLOR_WHITE;
        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"];
            if (BGFarbe == 0) {
                if (sgvMgdl >= zielbereichLow && sgvMgdl <= zielbereichHigh) {
                    sgvColor = farbeZielbereich;
                } else {
                    sgvColor = farbeAlarm;
                }
            }
        }

        var leftW = (width * 0.46).toNumber();
        var topY = pad;
        var bottomReserve = (height * 0.22).toNumber();
        var contentH = height - bottomReserve - topY;

        if (drawMascot) {
            var kind = AimicoState.mascotKind(sgvMgdl, zielbereichLow, zielbereichHigh);
            // Keep unicorn visible while waiting for first SGV
            if (kind.equals("none")) {
                kind = "inrange";
            }
            var bmp = AimicoState.mascotDrawable(kind);
            if (bmp != null) {
                var bw = bmp.getWidth();
                var mx = ((leftW - bw) / 2).toNumber();
                if (mx < pad) { mx = pad; }
                dc.drawBitmap(mx, topY + 4, bmp);
            }
        }

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        var loopY = topY + contentH - dc.getFontHeight(Gfx.FONT_SMALL) * 3 - 8;
        if (loopY < topY + 80) {
            loopY = topY + 80;
        }
        var loopX = pad;
        if (anzeigeIOB != null && anzeigeIOB.equals("") == false) {
            dc.drawText(loopX, loopY, Gfx.FONT_SMALL, anzeigeIOB, Gfx.TEXT_JUSTIFY_LEFT);
            loopY += dc.getFontHeight(Gfx.FONT_SMALL) + 2;
        }
        if (anzeigeBasal != null && anzeigeBasal.equals("") == false) {
            dc.drawText(loopX, loopY, Gfx.FONT_SMALL, anzeigeBasal, Gfx.TEXT_JUSTIFY_LEFT);
            loopY += dc.getFontHeight(Gfx.FONT_SMALL) + 2;
        }
        if (anzeigeCOB != null && anzeigeCOB.equals("") == false) {
            dc.drawText(loopX, loopY, Gfx.FONT_SMALL, anzeigeCOB, Gfx.TEXT_JUSTIFY_LEFT);
        }

        drawMiniGraph(dc, pad, topY + (drawMascot ? 100 : 20), leftW - pad * 2, 36, punkte, zielbereichLow, zielbereichHigh);

        var fontBg = Gfx.FONT_NUMBER_HOT;
        if (width < 280) {
            fontBg = Gfx.FONT_NUMBER_MEDIUM;
        }
        dc.setColor(sgvColor, Gfx.COLOR_TRANSPARENT);
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false) {
            sgvText = anzeigeSGV;
        }
        dc.drawText(width - pad, topY + 8, fontBg, sgvText, Gfx.TEXT_JUSTIFY_RIGHT);

        var metaY = topY + 8 + dc.getFontHeight(fontBg) - 4;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var ageStr = "";
        if (verzoegerung != null) {
            ageStr = verzoegerung.toString() + " m";
        }
        var deltaStr = "";
        if (anzeigeDelta != null && anzeigeDelta.equals("") == false) {
            deltaStr = anzeigeDelta;
        }
        var metaLine = ageStr;
        if (deltaStr.equals("") == false) {
            if (metaLine.equals("") == false) {
                metaLine = metaLine + "  ";
            }
            metaLine = metaLine + deltaStr;
        }
        if (metaLine.equals("") == false) {
            dc.drawText(width - pad - 40, metaY, Gfx.FONT_SMALL, metaLine, Gfx.TEXT_JUSTIFY_RIGHT);
        }

        if (auswahlPfeil != null) {
            var arrowBmp = AimicoState.arrowDrawable(auswahlPfeil);
            if (arrowBmp != null) {
                dc.drawBitmap(width - pad - arrowBmp.getWidth(), metaY + 2, arrowBmp);
            }
        }

        var actY = metaY + dc.getFontHeight(Gfx.FONT_SMALL) + 14;
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(width - pad, actY, Gfx.FONT_SMALL, stepsStr + " steps", Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(width - pad, actY + dc.getFontHeight(Gfx.FONT_SMALL) + 2, Gfx.FONT_SMALL, hrStr + " bpm", Gfx.TEXT_JUSTIFY_RIGHT);

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, 4, Gfx.FONT_TINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }

        // Status / error: compact line above the clock (does not cover mascot)
        if (anzeigeFehler != null && anzeigeFehler.equals("") == false) {
            var err = anzeigeFehler;
            if (err.equals("Wait max.\n5 min")) {
                err = "Waiting for BG…";
            }
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height - pad - dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM) - dc.getFontHeight(Gfx.FONT_TINY) - 6, Gfx.FONT_TINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var timeFont = Gfx.FONT_NUMBER_MEDIUM;
        if (width >= 360) {
            timeFont = Gfx.FONT_NUMBER_HOT;
        }
        dc.drawText(width / 2, height - pad - dc.getFontHeight(timeFont), timeFont, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function hideLabel(view, id) {
        var d = view.findDrawableById(id);
        if (d != null) {
            d.setText("");
            d.setLocation(-999, -999);
        }
    }

    function drawMiniGraph(dc, x, y, w, h, punkte, low, high) {
        if (punkte == null || (punkte instanceof Lang.Array) == false || punkte.size() < 2) {
            return;
        }
        if (w < 20 || h < 10) {
            return;
        }
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(x, y, w, h);

        var n = punkte.size();
        if (n > 18) { n = 18; }
        var minV = low;
        var maxV = high;
        for (var i = 0; i < n; i++) {
            if (punkte[i]["sgv"] == null) { continue; }
            var v = punkte[i]["sgv"];
            if (v < minV) { minV = v; }
            if (v > maxV) { maxV = v; }
        }
        if (maxV <= minV) {
            maxV = minV + 1;
        }
        var span = (maxV - minV).toFloat();
        for (var j = 0; j < n; j++) {
            if (punkte[j]["sgv"] == null) { continue; }
            var vv = punkte[j]["sgv"].toFloat();
            var px = x + w - 2 - ((j.toFloat() / (n - 1).toFloat()) * (w - 4)).toNumber();
            var py = y + h - 2 - (((vv - minV.toFloat()) / span) * (h - 4)).toNumber();
            var col = Gfx.COLOR_GREEN;
            if (vv < low) { col = Gfx.COLOR_RED; }
            else if (vv > high) { col = Gfx.COLOR_YELLOW; }
            dc.setColor(col, Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 2);
        }
    }

}
