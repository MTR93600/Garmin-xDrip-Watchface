using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Lang as Lang;

//! AIMICO Split Mirror layout (layoutStyle=2).
//! Portrait left / metrics right; loop + time never overlap.
module CGMWatchfaceE2 {

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
        AimicoDraw.hideClassicLabels(view);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var pad = width >= 360 ? 14 : 10;

        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        AimicoDraw.drawHeader(dc, pad, datum, steps, heartrate);

        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"];
        }
        var sgvColor = AimicoDraw.sgvColor(sgvMgdl, zielbereichLow, zielbereichHigh, farbeZielbereich, farbeAlarm, BGFarbe);

        // Compact time (MEDIUM) so metrics have room — HOT was eating the stack
        var timeFont = Gfx.FONT_NUMBER_MEDIUM;
        var timeH = dc.getFontHeight(timeFont);
        var err = AimicoDraw.friendlyError(anzeigeFehler);
        var statusH = 0;
        if (err.equals("") == false) {
            statusH = dc.getFontHeight(Gfx.FONT_TINY) + 4;
        }
        var timeY = height - pad - timeH;
        var statusY = timeY - statusH;
        var stripH = dc.getFontHeight(Gfx.FONT_TINY) + 6;
        var stripY = statusY - stripH;
        if (statusH == 0) {
            stripY = timeY - stripH;
        }

        var headerH = AimicoDraw.headerHeight(dc);
        var bodyTop = pad + headerH;
        // Keep delta above this ceiling; then drop IOB strip a bit lower for air
        var bodyBottom = stripY - 22;
        stripY = stripY + 8;
        var bodyH = bodyBottom - bodyTop;
        if (bodyH < 70) {
            bodyH = 70;
        }
        var bodyY = bodyTop;

        var leftW = ((width - pad * 2) * 40) / 100;
        var gap = 8;
        var leftX = pad;
        var rightX = pad + leftW + gap;
        var rightW = width - pad - rightX;

        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad + leftW + gap / 2, bodyY + 2, pad + leftW + gap / 2, bodyBottom - 2);

        var drawMascot = AimicoDraw.shouldShowMascot(isHighPower);
        if (drawMascot) {
            var kind = AimicoState.mascotKind(sgvMgdl, zielbereichLow, zielbereichHigh);
            if (kind.equals("none")) {
                kind = "inrange";
            }
            var bmp = AimicoState.mascotDrawable(kind);
            if (bmp != null) {
                var maxH = bodyH - 6;
                var maxW = leftW - 4;
                var bw = bmp.getWidth();
                var bh = bmp.getHeight();
                var dh = bh;
                var dw = bw;
                if (bh > maxH && bh > 0) {
                    dh = maxH;
                    dw = ((bw * maxH) / bh).toNumber();
                }
                if (dw > maxW && dw > 0) {
                    dw = maxW;
                    dh = ((bh * maxW) / bw).toNumber();
                }
                var mx = leftX + ((leftW - dw) / 2).toNumber();
                var my = bodyY + ((bodyH - dh) / 2).toNumber();
                AimicoDraw.drawMascotScaled(dc, bmp, mx, my, dw, dh);
            }
        }

        // Right pane: BG on top, delta row ALWAYS reserved under it
        var deltaH = dc.getFontHeight(Gfx.FONT_SMALL) + 12;
        var bgAreaH = bodyH - deltaH - 8;
        if (bgAreaH < 40) {
            bgAreaH = 40;
        }

        var fontBg = Gfx.FONT_NUMBER_MEDIUM;
        var hotH = dc.getFontHeight(Gfx.FONT_NUMBER_HOT);
        if (bgAreaH >= hotH && rightW >= 150) {
            fontBg = Gfx.FONT_NUMBER_HOT;
        }
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false) {
            sgvText = anzeigeSGV;
        }

        var stackX = rightX;
        var bgY = bodyY + 4;
        dc.setColor(sgvColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(stackX, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_LEFT);

        // Delta under BG; hard max Y so arrow cannot invade strip
        var rowY = bodyBottom - deltaH;
        var minRowY = bgY + dc.getFontHeight(fontBg) + 4;
        if (rowY < minRowY) {
            rowY = minRowY;
        }
        AimicoDraw.drawDeltaRowLeft(dc, stackX, rowY, bodyBottom, verzoegerung, anzeigeDelta, auswahlPfeil);

        // Full-width loop strip above time (never over clock)
        var loop = "";
        if (anzeigeIOB != null && anzeigeIOB.equals("") == false) {
            loop = anzeigeIOB;
        }
        if (anzeigeBasal != null && anzeigeBasal.equals("") == false) {
            if (loop.equals("") == false) {
                loop = loop + " · ";
            }
            loop = loop + anzeigeBasal;
        }
        if (anzeigeCOB != null && anzeigeCOB.equals("") == false) {
            if (loop.equals("") == false) {
                loop = loop + " · ";
            }
            loop = loop + anzeigeCOB;
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (loop.equals("") == false) {
            dc.drawText(width / 2, stripY, Gfx.FONT_TINY, loop, Gfx.TEXT_JUSTIFY_CENTER);
        }

        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, statusY, Gfx.FONT_TINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(width / 2, timeY, timeFont, timeString, Gfx.TEXT_JUSTIFY_CENTER);
    }

}
