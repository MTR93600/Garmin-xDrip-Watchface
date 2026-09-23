using Toybox.Graphics as Gfx;
using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Lang as Lang;

//! AIMICO Card Band layout (layoutStyle=1) — repaired.
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

        var headerH = AimicoDraw.headerHeight(dc);
        var footerH = AimicoDraw.footerReserve(dc, pad);
        var stripH = dc.getFontHeight(Gfx.FONT_TINY) * 2 + 10;

        var cardTop = pad + headerH;
        var cardH = height - cardTop - footerH - stripH;
        if (cardH < 100) {
            cardH = 100;
        }
        var cardX = pad;
        var cardW = width - pad * 2;
        var cardY = cardTop;
        var innerPad = 8;

        // Black card + subtle border
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRoundedRectangle(cardX, cardY, cardW, cardH, 14);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(cardX, cardY, cardW, cardH, 14);

        var drawMascot = AimicoDraw.shouldShowMascot(isHighPower);
        var mascotMaxH = cardH - innerPad * 2;
        var mascotMaxW = ((cardW * 45) / 100).toNumber();

        if (drawMascot) {
            var kind = AimicoState.mascotKind(sgvMgdl, zielbereichLow, zielbereichHigh);
            if (kind.equals("none")) {
                kind = "inrange";
            }
            var bmp = AimicoState.mascotDrawable(kind);
            if (bmp != null) {
                var bh = bmp.getHeight();
                var bw = bmp.getWidth();
                var dh = bh;
                var dw = bw;
                if (bh > mascotMaxH && bh > 0) {
                    dh = mascotMaxH;
                    dw = ((bw * mascotMaxH) / bh).toNumber();
                }
                if (dw > mascotMaxW && dw > 0) {
                    dw = mascotMaxW;
                    dh = ((bh * mascotMaxW) / bw).toNumber();
                }
                var mx = cardX + innerPad;
                var my = cardY + ((cardH - dh) / 2).toNumber();
                AimicoDraw.drawMascotScaled(dc, bmp, mx, my, dw, dh);
            }
        }

        var fontBg = Gfx.FONT_NUMBER_HOT;
        if (width < 300) {
            fontBg = Gfx.FONT_NUMBER_MEDIUM;
        }
        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false) {
            sgvText = anzeigeSGV;
        }
        var rightX = cardX + cardW - innerPad;
        var bgY = cardY + innerPad + 2;
        dc.setColor(sgvColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(rightX, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_RIGHT);

        // Delta row clearly below BG glyphs (NUMBER_HOT needs full height + gap)
        var rowY = bgY + dc.getFontHeight(fontBg) + 4;
        var rowH = dc.getFontHeight(Gfx.FONT_SMALL);
        if (rowY + rowH > cardY + cardH - 4) {
            // Fall back to medium BG so delta fits under number
            fontBg = Gfx.FONT_NUMBER_MEDIUM;
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.fillRectangle(cardX + cardW / 2, cardY + 2, cardW / 2 - 2, cardH - 4);
            dc.setColor(sgvColor, Gfx.COLOR_TRANSPARENT);
            dc.drawText(rightX, bgY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_RIGHT);
            rowY = bgY + dc.getFontHeight(fontBg) + 4;
        }
        AimicoDraw.drawDeltaRow(dc, rightX, rowY, verzoegerung, anzeigeDelta, auswahlPfeil);

        // Loop strip: two lines under card
        var stripY = cardY + cardH + 4;
        var line1 = "";
        if (anzeigeIOB != null && anzeigeIOB.equals("") == false) {
            line1 = anzeigeIOB;
        }
        if (anzeigeBasal != null && anzeigeBasal.equals("") == false) {
            if (line1.equals("") == false) {
                line1 = line1 + " · ";
            }
            line1 = line1 + anzeigeBasal;
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if (line1.equals("") == false) {
            dc.drawText(pad, stripY, Gfx.FONT_TINY, line1, Gfx.TEXT_JUSTIFY_LEFT);
        }
        if (anzeigeCOB != null && anzeigeCOB.equals("") == false) {
            dc.drawText(pad, stripY + dc.getFontHeight(Gfx.FONT_TINY) + 1, Gfx.FONT_TINY, anzeigeCOB, Gfx.TEXT_JUSTIFY_LEFT);
        }

        AimicoDraw.drawTimeAndStatus(dc, pad, timeString, anzeigeFehler);
    }

}
