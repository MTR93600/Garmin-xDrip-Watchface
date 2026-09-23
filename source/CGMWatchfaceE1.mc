using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Lang as Lang;

//! AIMICO Card Band layout (layoutStyle=1).
//! One horizontal card: unicorn + BG/delta/arrow; loop strip; time bottom.
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
            } else {
                sgvColor = Gfx.COLOR_WHITE;
            }
        }

        // Header: date left, steps · HR right
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, pad - 2, Gfx.FONT_TINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(width - pad, pad - 2, Gfx.FONT_TINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);

        var headerH = dc.getFontHeight(Gfx.FONT_TINY) + 8;
        var timeFont = Gfx.FONT_NUMBER_MEDIUM;
        if (width >= 360) {
            timeFont = Gfx.FONT_NUMBER_HOT;
        }
        var timeH = dc.getFontHeight(timeFont);
        var statusH = dc.getFontHeight(Gfx.FONT_TINY) + 4;
        var footerH = timeH + statusH + pad + 4;

        // Card band region
        var cardTop = pad + headerH;
        var cardH = height - cardTop - footerH - 6;
        if (cardH < 90) {
            cardH = 90;
        }
        var cardX = pad;
        var cardW = width - pad * 2;
        var cardY = cardTop;

        // Card background
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
        // softer dark panel via fill rounded approx
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 16);

        var innerPad = 8;
        var uniMaxH = cardH - innerPad * 2;
        if (uniMaxH > 150) {
            uniMaxH = 150;
        }

        // --- Unicorn (left of card) ---
        if (drawMascot) {
            var kind = AimicoState.mascotKind(sgvMgdl, zielbereichLow, zielbereichHigh);
            if (kind.equals("none")) {
                kind = "inrange";
            }
            var bmp = AimicoState.mascotDrawable(kind);
            if (bmp != null) {
                var bw = bmp.getWidth();
                var bh = bmp.getHeight();
                var mx = cardX + innerPad;
                var my = cardY + ((cardH - bh) / 2).toNumber();
                if (my < cardY + 4) {
                    my = cardY + 4;
                }
                dc.drawBitmap(mx, my, bmp);
            }
        }

        // --- BG + age + delta + AIMICO arrow (right of card) ---
        var fontBg = Gfx.FONT_NUMBER_HOT;
        if (width < 300) {
            fontBg = Gfx.FONT_NUMBER_MEDIUM;
        }
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false) {
            sgvText = anzeigeSGV;
        }
        var rightX = width - pad - innerPad;
        var bgY = cardY + innerPad + 2;
        dc.setColor(sgvColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(rightX, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_RIGHT);

        // Row under BG: "3 m" + delta + arrow bitmap
        var rowY = bgY + dc.getFontHeight(fontBg) - 2;
        var ageStr = "";
        if (verzoegerung != null) {
            var vz = verzoegerung.toString();
            if (vz.equals("--") == false && vz.equals("999") == false) {
                ageStr = vz + " m";
            }
        }
        var deltaStr = "";
        if (anzeigeDelta != null && anzeigeDelta.equals("") == false && anzeigeDelta.equals("--") == false) {
            deltaStr = anzeigeDelta;
        }

        // Arrow first (rightmost), then delta, then age — reading toward the number
        var cursorX = rightX;
        if (auswahlPfeil != null) {
            var arrowBmp = AimicoState.arrowDrawable(auswahlPfeil);
            if (arrowBmp != null) {
                var aw = arrowBmp.getWidth();
                var ah = arrowBmp.getHeight();
                cursorX = cursorX - aw;
                var ay = rowY + (dc.getFontHeight(Gfx.FONT_SMALL) - ah) / 2;
                dc.drawBitmap(cursorX, ay.toNumber(), arrowBmp);
                cursorX = cursorX - 6;
            }
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if (deltaStr.equals("") == false) {
            dc.drawText(cursorX, rowY, Gfx.FONT_SMALL, deltaStr, Gfx.TEXT_JUSTIFY_RIGHT);
            cursorX = cursorX - dc.getTextWidthInPixels(deltaStr, Gfx.FONT_SMALL) - 8;
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (ageStr.equals("") == false) {
            dc.drawText(cursorX, rowY, Gfx.FONT_SMALL, ageStr, Gfx.TEXT_JUSTIFY_RIGHT);
        }

        // Loop strip under card
        var stripY = cardY + cardH + 6;
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        var loopParts = "";
        if (anzeigeIOB != null && anzeigeIOB.equals("") == false) {
            loopParts = anzeigeIOB;
        }
        if (anzeigeBasal != null && anzeigeBasal.equals("") == false) {
            if (loopParts.equals("") == false) {
                loopParts = loopParts + " · ";
            }
            loopParts = loopParts + anzeigeBasal;
        }
        if (anzeigeCOB != null && anzeigeCOB.equals("") == false) {
            if (loopParts.equals("") == false) {
                loopParts = loopParts + " · ";
            }
            loopParts = loopParts + anzeigeCOB;
        }
        if (loopParts.equals("") == false) {
            dc.drawText(pad, stripY, Gfx.FONT_TINY, loopParts, Gfx.TEXT_JUSTIFY_LEFT);
        }

        // Status above clock
        if (anzeigeFehler != null && anzeigeFehler.equals("") == false) {
            var err = anzeigeFehler;
            if (err.equals("Wait max.\n5 min")) {
                err = "Waiting for BG…";
            } else if (err.equals("Error: -300\nSettings?")) {
                err = "No link to phone/AAPS";
            } else if (err.equals("Error: -300")) {
                err = "No link to phone/AAPS";
            }
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height - pad - timeH - statusH, Gfx.FONT_TINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }

        // Time
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height - pad - timeH, timeFont, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function hideLabel(view, id) {
        var d = view.findDrawableById(id);
        if (d != null) {
            d.setText("");
            d.setLocation(-999, -999);
        }
    }

}
