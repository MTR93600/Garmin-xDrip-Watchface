using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;

//! Shared AIMICO chrome: header, time, errors, code-drawn trend arrows.
module AimicoDraw {

    function shouldShowMascot(isHighPower) {
        var showMascotProp = App.getApp().getProperty("showMascot");
        var showMascotMode = showMascotProp != null ? showMascotProp.toNumber() : 1;
        if (showMascotMode == 0) {
            return false;
        }
        if (showMascotMode == 2 && isHighPower == false) {
            return false;
        }
        return true;
    }

    function sgvColor(sgvMgdl, zielbereichLow, zielbereichHigh, farbeZielbereich, farbeAlarm, BGFarbe) {
        if (BGFarbe != 0) {
            return Gfx.COLOR_WHITE;
        }
        if (sgvMgdl == null) {
            return Gfx.COLOR_WHITE;
        }
        if (sgvMgdl >= zielbereichLow && sgvMgdl <= zielbereichHigh) {
            return farbeZielbereich;
        }
        return farbeAlarm;
    }

    function friendlyError(anzeigeFehler) {
        if (anzeigeFehler == null || anzeigeFehler.equals("")) {
            return "";
        }
        if (anzeigeFehler.equals("Wait max.\n5 min")) {
            return "Waiting for BG…";
        }
        if (anzeigeFehler.equals("Error: -300\nSettings?") || anzeigeFehler.equals("Error: -300")) {
            return "No link to phone/AAPS";
        }
        return anzeigeFehler;
    }

    function hideClassicLabels(view) {
        hideLabel(view, "TimeLabel");
        hideLabel(view, "DateLabel");
        hideLabel(view, "sgvLabel");
        hideLabel(view, "deltaLabel");
        hideLabel(view, "verzLabel");
        hideLabel(view, "iobLabel");
        hideLabel(view, "cobLabel");
        hideLabel(view, "basalLabel");
    }

    function hideLabel(view, id) {
        var d = view.findDrawableById(id);
        if (d != null) {
            d.setText("");
            d.setLocation(-999, -999);
        }
    }

    function drawHeader(dc, pad, datum, steps, heartrate) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (datum != null) {
            dc.drawText(pad, pad - 2, Gfx.FONT_TINY, datum, Gfx.TEXT_JUSTIFY_LEFT);
        }
        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.drawText(dc.getWidth() - pad, pad - 2, Gfx.FONT_TINY, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);
    }

    function headerHeight(dc) {
        return dc.getFontHeight(Gfx.FONT_TINY) + 8;
    }

    function timeFontFor(width) {
        if (width >= 360) {
            return Gfx.FONT_NUMBER_HOT;
        }
        return Gfx.FONT_NUMBER_MEDIUM;
    }

    function drawTimeAndStatus(dc, pad, timeString, anzeigeFehler) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var timeFont = timeFontFor(width);
        var timeH = dc.getFontHeight(timeFont);
        var statusH = dc.getFontHeight(Gfx.FONT_TINY) + 4;
        var err = friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height - pad - timeH - statusH, Gfx.FONT_TINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height - pad - timeH, timeFont, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

    function footerReserve(dc, pad) {
        var timeFont = timeFontFor(dc.getWidth());
        var timeH = dc.getFontHeight(timeFont);
        var statusH = dc.getFontHeight(Gfx.FONT_TINY) + 4;
        return timeH + statusH + pad + 4;
    }

    //! Draw trend arrow with tip at rightX, vertically centered on midY. Returns width used.
    function drawTrendArrow(dc, rightX, midY, auswahlPfeil) {
        if (auswahlPfeil == null) {
            return 0;
        }
        var s = 18;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(4);

        if (auswahlPfeil.equals("Flat")) {
            var x0 = rightX - 2 * s - 2;
            dc.drawLine(x0, midY, rightX - 2, midY);
            dc.fillPolygon([[rightX, midY], [rightX - s - 2, midY - s / 2 - 2], [rightX - s - 2, midY + s / 2 + 2]]);
            return 2 * s + 6;
        }
        if (auswahlPfeil.equals("SingleUp")) {
            var x = rightX - s;
            dc.drawLine(x, midY + s + 2, x, midY - s + 2);
            dc.fillPolygon([[x, midY - s], [x - s / 2 - 3, midY], [x + s / 2 + 3, midY]]);
            return s + 8;
        }
        if (auswahlPfeil.equals("SingleDown")) {
            var x = rightX - s;
            dc.drawLine(x, midY - s - 2, x, midY + s - 2);
            dc.fillPolygon([[x, midY + s], [x - s / 2 - 3, midY], [x + s / 2 + 3, midY]]);
            return s + 8;
        }
        if (auswahlPfeil.equals("FortyFiveUp")) {
            var x0 = rightX - 2 * s;
            dc.drawLine(x0, midY + s / 2 + 2, rightX - 4, midY - s / 2);
            dc.fillPolygon([[rightX, midY - s / 2], [rightX - s - 2, midY - s / 2 - 2], [rightX - 2, midY + s / 2]]);
            return 2 * s + 6;
        }
        if (auswahlPfeil.equals("FortyFiveDown")) {
            var x0 = rightX - 2 * s;
            dc.drawLine(x0, midY - s / 2 - 2, rightX - 4, midY + s / 2);
            dc.fillPolygon([[rightX, midY + s / 2], [rightX - s - 2, midY + s / 2 + 2], [rightX - 2, midY - s / 2]]);
            return 2 * s + 6;
        }
        if (auswahlPfeil.equals("DoubleUp")) {
            var x = rightX - s;
            dc.drawLine(x, midY + s + 2, x, midY - 4);
            dc.fillPolygon([[x, midY - s], [x - s / 2 - 3, midY - 2], [x + s / 2 + 3, midY - 2]]);
            dc.fillPolygon([[x, midY], [x - s / 2 - 3, midY + s - 2], [x + s / 2 + 3, midY + s - 2]]);
            return s + 8;
        }
        if (auswahlPfeil.equals("DoubleDown")) {
            var x = rightX - s;
            dc.drawLine(x, midY - s - 2, x, midY + 4);
            dc.fillPolygon([[x, midY + s], [x - s / 2 - 3, midY + 2], [x + s / 2 + 3, midY + 2]]);
            dc.fillPolygon([[x, midY], [x - s / 2 - 3, midY - s + 2], [x + s / 2 + 3, midY - s + 2]]);
            return s + 8;
        }
        return 0;
    }

    //! Draw age + delta + classic arrow, left-aligned. Arrow stays in-row (no overlap below).
    function drawDeltaRowLeft(dc, leftX, rowY, maxBottom, verzoegerung, anzeigeDelta, auswahlPfeil) {
        var font = Gfx.FONT_SMALL;
        var gap = 16;
        var x = leftX;
        var fh = dc.getFontHeight(font);

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

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (ageStr.equals("") == false) {
            dc.drawText(x, rowY, font, ageStr, Gfx.TEXT_JUSTIFY_LEFT);
            var tw = dc.getTextWidthInPixels(ageStr, font);
            if (tw < 8) {
                tw = 8 * ageStr.length();
            }
            x = x + tw + gap;
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if (deltaStr.equals("") == false) {
            dc.drawText(x, rowY, font, deltaStr, Gfx.TEXT_JUSTIFY_LEFT);
            var tw2 = dc.getTextWidthInPixels(deltaStr, font);
            if (tw2 < 8) {
                tw2 = 8 * deltaStr.length();
            }
            x = x + tw2 + gap;
        }

        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        var ah = 36;
        if (maxBottom != null && rowY + ah > maxBottom) {
            ah = maxBottom - rowY;
            if (ah < 24) {
                ah = 24;
            }
        }
        if (bmp != null) {
            var aw = ah;
            var ay = rowY + ((fh - ah) / 2).toNumber();
            if (ay < rowY) {
                ay = rowY;
            }
            if (maxBottom != null && ay + ah > maxBottom) {
                ay = maxBottom - ah;
            }
            dc.drawScaledBitmap(x, ay, aw, ah, bmp);
        }
        return fh;
    }

    //! Legacy right-aligned delta row (Card layout).
    function drawDeltaRow(dc, rightX, rowY, verzoegerung, anzeigeDelta, auswahlPfeil) {
        var font = Gfx.FONT_SMALL;
        var fh = dc.getFontHeight(font);
        var gap = 16;
        var cursorX = rightX;

        var bmp = AimicoState.classicArrowDrawable(auswahlPfeil);
        var ah = 36;
        if (bmp != null) {
            var aw = ah;
            cursorX = cursorX - aw;
            var ay = rowY + ((fh - ah) / 2).toNumber();
            if (ay < rowY) {
                ay = rowY;
            }
            dc.drawScaledBitmap(cursorX, ay, aw, ah, bmp);
            cursorX = cursorX - gap;
        } else {
            var midY = rowY + fh / 2;
            var aw2 = drawTrendArrow(dc, cursorX, midY, auswahlPfeil);
            if (aw2 > 0) {
                cursorX = cursorX - aw2 - gap;
            }
        }

        var deltaStr = "";
        if (anzeigeDelta != null && anzeigeDelta.equals("") == false && anzeigeDelta.equals("--") == false) {
            deltaStr = anzeigeDelta;
        }
        var ageStr = "";
        if (verzoegerung != null) {
            var vz = verzoegerung.toString();
            if (vz.equals("--") == false && vz.equals("999") == false) {
                ageStr = vz + " m";
            }
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if (deltaStr.equals("") == false) {
            dc.drawText(cursorX, rowY, font, deltaStr, Gfx.TEXT_JUSTIFY_RIGHT);
            var tw = dc.getTextWidthInPixels(deltaStr, font);
            if (tw < 8) {
                tw = 8 * deltaStr.length();
            }
            cursorX = cursorX - tw - gap;
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (ageStr.equals("") == false) {
            dc.drawText(cursorX, rowY, font, ageStr, Gfx.TEXT_JUSTIFY_RIGHT);
        }
    }

    function drawMascotScaled(dc, bmp, x, y, maxW, maxH) {
        if (bmp == null) {
            return;
        }
        var bw = bmp.getWidth();
        var bh = bmp.getHeight();
        var dw = bw;
        var dh = bh;
        if (bh > maxH && bh > 0) {
            dh = maxH;
            dw = ((bw * maxH) / bh).toNumber();
        }
        if (dw > maxW && dw > 0) {
            dw = maxW;
            dh = ((bh * maxW) / bw).toNumber();
        }
        if (dw < 1) { dw = 1; }
        if (dh < 1) { dh = 1; }
        if (dw != bw || dh != bh) {
            dc.drawScaledBitmap(x, y, dw, dh, bmp);
        } else {
            dc.drawBitmap(x, y, bmp);
        }
    }

}
