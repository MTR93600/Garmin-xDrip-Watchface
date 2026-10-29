using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg;

//! CONCEPT — Téléscripteur (layoutStyle=10).
//! Green-phosphor AIMI log: scrolling journal + fixed live strip.
//! Layout calibrated for Venu X1 448×486 (no AffineTransform / BufferedBitmap).
module TeleDrawing {

    const STATE_NORMAL = 0;
    const STATE_HYPO = 1;
    const STATE_HYPER = 3;

    const COL_BG = 0x050805;
    const COL_DIM = 0x1A6633;
    const COL_MID = 0x2AB84A;
    const COL_HI = 0xA8FFB8;
    const COL_GREEN = 0x33FF66;
    const COL_EVT = 0xE0B040;
    const COL_MODE = 0xFFCC66;
    const COL_RED = 0xFF5544;
    const COL_AMBER = 0xE08040;
    const COL_RULE = 0x143214;

    //! kind: 0=sgv, 1=smb, 2=mode, 3=snap, 4=sep
    const KIND_SGV = 0;
    const KIND_SMB = 1;
    const KIND_MODE = 2;
    const KIND_SNAP = 3;
    const KIND_SEP = 4;

    //! Venu X1 448×486: live strip remonté; bottomSafe gère le coin arrondi.
    const LIVE_H_VENUX1 = 100;
    const LIVE_H_SMALL = 86;
    const LOG_LINE_MIN = 12;
    const CORNER_SAFE = 12; // right inset so TIR clears the bezel

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

    function drawSheet(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(COL_BG, COL_BG);
        dc.fillRectangle(0, 0, w, h);
    }

    //! Header without title: date+time left, steps · HR right (corner-safe).
    function drawHeader(dc, pad, datum, timeString, steps, heartrate) {
        var w = dc.getWidth();
        var y = pad - 2;
        var fnt = Gfx.FONT_XTINY;
        var rightPad = pad + CORNER_SAFE;

        var left = "";
        if (datum != null) { left = datum.toString(); }
        if (timeString != null) {
            if (left.equals("") == false) { left = left + "  "; }
            left = left + timeString.toString();
        }
        dc.setColor(COL_MID, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, y, fnt, left, Gfx.TEXT_JUSTIFY_LEFT);

        var stepsStr = steps != null ? steps.toString() : "--";
        var hrStr = heartrate != null ? heartrate.toString() : "--";
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - rightPad, y, fnt, stepsStr + " · " + hrStr, Gfx.TEXT_JUSTIFY_RIGHT);

        var hy = y + dc.getFontHeight(fnt) + 2;
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad, hy, w - rightPad, hy);
        return hy + 3;
    }

    //! Return recommended live-strip height for this screen.
    function liveHeight(screenH) {
        if (screenH >= 460) { return LIVE_H_VENUX1; }
        return LIVE_H_SMALL;
    }

    //! Log pitch: XTINY is CIQ floor — compress to ~12–14 px/line on Venu X1.
    function logLineHeight(dc) {
        var h = dc.getFontHeight(Gfx.FONT_XTINY) - 5;
        if (h < LOG_LINE_MIN) { h = LOG_LINE_MIN; }
        return h;
    }

    //! rows: Array of Dictionaries { "kind", "text" }
    //! Bottom-aligned so WAIT_ sits just above the live strip (no empty gap).
    function drawLog(dc, pad, y, w, h, rows, state) {
        var fnt = Gfx.FONT_XTINY;
        var lineH = logLineHeight(dc);
        var maxLines = h / lineH;
        if (maxLines < 1) { maxLines = 1; }

        var start = 0;
        var count = 0;
        if (rows != null) {
            count = rows.size();
            if (count > maxLines) {
                start = count - maxLines;
                count = maxLines;
            }
        }
        // Anchor last row at bottom of log band
        var ly = y + h - (count * lineH);
        if (ly < y) { ly = y; }
        var i = start;
        while (rows != null && i < rows.size()) {
            var row = rows[i];
            if (row != null && row["text"] != null) {
                var col = colorForKind(row["kind"], state);
                dc.setColor(col, Gfx.COLOR_TRANSPARENT);
                dc.drawText(pad, ly, fnt, row["text"], Gfx.TEXT_JUSTIFY_LEFT);
            }
            ly += lineH;
            i++;
        }
    }

    function colorForKind(kind, state) {
        if (kind == KIND_SMB) { return COL_EVT; }
        if (kind == KIND_MODE) { return COL_MODE; }
        if (kind == KIND_SNAP || kind == KIND_SEP) { return COL_DIM; }
        if (state == STATE_HYPO) { return COL_RED; }
        if (state == STATE_HYPER) { return COL_AMBER; }
        if (kind == KIND_SGV) { return COL_MID; }
        return COL_DIM;
    }

    //! Live strip — SGV remonté + ligne métriques XTINY compacte (TIR visible).
    function drawLiveStrip(dc, pad, y, w, h, sgvText, deltaNum, ageMin, mode, targetNum, tbr, iob, tir, state) {
        var stripTop = y;
        var contentRight = pad + w - CORNER_SAFE;
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad, stripTop, contentRight, stripTop);

        var col = COL_HI;
        if (state == STATE_HYPO) { col = COL_RED; }
        else if (state == STATE_HYPER) { col = COL_AMBER; }

        var fnt = Gfx.FONT_XTINY;
        var tinyH = dc.getFontHeight(fnt);
        // MEDIUM leaves room for metrics under the glyph; LARGE overlapped row2 on device
        var fontBg = Gfx.FONT_MEDIUM;
        var bgH = dc.getFontHeight(fontBg);

        var sgvY = stripTop + 2;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, sgvY, fontBg, sgvText, Gfx.TEXT_JUSTIFY_LEFT);

        var tw = dc.getTextWidthInPixels(sgvText, fontBg);
        var dStr = "d--";
        if (deltaNum != null) {
            dStr = deltaNum > 0 ? ("d+" + deltaNum.toString()) : ("d" + deltaNum.toString());
        }
        var ageStr = "--";
        if (ageMin != null) { ageStr = ageMin.toString() + "m"; }
        var meta = dStr + " " + ageStr;
        var unitStr = "mg/dL";
        if (mode != null && mode.equals("") == false) {
            unitStr = mode.toString();
        }
        var metaY = sgvY + ((bgH - tinyH) / 2);
        var metaX = pad + tw + 8;
        dc.setColor(COL_MID, Gfx.COLOR_TRANSPARENT);
        dc.drawText(metaX, metaY, fnt, meta, Gfx.TEXT_JUSTIFY_LEFT);
        var unitX = metaX + dc.getTextWidthInPixels(meta, fnt) + 6;
        if (unitX + dc.getTextWidthInPixels(unitStr, fnt) <= contentRight) {
            dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
            dc.drawText(unitX, metaY, fnt, unitStr, Gfx.TEXT_JUSTIFY_LEFT);
        }

        // Metrics: compact separators, no char-chop (that was cutting "TIR --" → "TIR-")
        var row2Y = sgvY + bgH;
        if (row2Y + tinyH > stripTop + h - 3) {
            row2Y = stripTop + h - tinyH - 3;
        }
        var tgtV = targetNum != null ? targetNum.toString() : "--";
        var tbrV = compactTbr(tbr);
        var iobV = compactIob(iob);
        var tirV = tir != null ? (tir.toString() + "%") : "--";
        var metrics = "TGT " + tgtV + " · TBR " + tbrV + " · IOB " + iobV + " · TIR " + tirV;
        var maxW = contentRight - pad;
        if (dc.getTextWidthInPixels(metrics, fnt) > maxW) {
            metrics = "TGT " + tgtV + " TBR " + tbrV + " IOB " + iobV + " TIR " + tirV;
        }
        if (dc.getTextWidthInPixels(metrics, fnt) > maxW) {
            metrics = tgtV + " " + tbrV + " " + iobV + " TIR " + tirV;
        }
        dc.setColor(COL_MID, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, row2Y, fnt, metrics, Gfx.TEXT_JUSTIFY_LEFT);
    }

    function compactIob(iob) {
        if (iob == null || iob.equals("")) { return "--"; }
        var s = iob.toString();
        if (s.length() >= 2) {
            var tail = s.substring(s.length() - 2, s.length());
            if (tail.equals(" U")) {
                s = s.substring(0, s.length() - 2);
            }
        }
        return s;
    }

    function compactTbr(basal) {
        if (basal == null || basal.equals("") || basal.equals("-- %") || basal.equals("--")) {
            return "--";
        }
        var s = basal.toString();
        var slash = -1;
        var i = 0;
        while (i < s.length()) {
            if (s.substring(i, i + 1).equals("/")) { slash = i; break; }
            i++;
        }
        if (slash >= 0 && slash + 1 < s.length()) {
            return s.substring(slash + 1, s.length()) + "%";
        }
        return s;
    }

    //! Format HH:MM from unix seconds (Long-safe via Moment).
    function formatHm(sec) {
        if (sec == null) { return "--:--"; }
        var s = sec;
        if (s > 2000000000) {
            s = s / 1000;
        }
        var moment = new Time.Moment(s);
        var info = Greg.info(moment, Time.FORMAT_SHORT);
        var hh = info.hour;
        var mm = info.min;
        var hs = hh < 10 ? ("0" + hh.toString()) : hh.toString();
        var ms = mm < 10 ? ("0" + mm.toString()) : mm.toString();
        return hs + ":" + ms;
    }

    //! Same magnitude rule as CGMWatchfaceView.minutesFromTimestamp.
    function toEpochSec(timestamp) {
        if (timestamp == null) { return null; }
        var now = Time.now().value();
        var ts = timestamp;
        if (ts > now + 86400 || ts > 2000000000) {
            return ts / 1000;
        }
        return ts;
    }

}
