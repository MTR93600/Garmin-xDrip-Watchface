using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg;

//! CONCEPT — Téléscripteur (layoutStyle=10).
//! Green-phosphor AIMI log: scrolling journal + fixed live strip.
//! No AffineTransform / BufferedBitmap (Venu X1 IQ! lesson).
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

    function drawHeader(dc, pad, datum, timeString) {
        var w = dc.getWidth();
        var y = pad - 2;
        var fnt = Gfx.FONT_XTINY;
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, y, fnt, "AIMI LOG", Gfx.TEXT_JUSTIFY_LEFT);
        var mid = "";
        if (datum != null) { mid = datum.toString() + "  "; }
        if (timeString != null) { mid = mid + timeString.toString(); }
        dc.setColor(COL_MID, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, fnt, mid, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w - pad, y, fnt, "CH1", Gfx.TEXT_JUSTIFY_RIGHT);
        var hy = y + dc.getFontHeight(fnt) + 2;
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad, hy, w - pad, hy);
        return hy + 3;
    }

    //! rows: Array of Dictionaries { "kind", "text" }
    //! XTINY is the smallest system font — tighten line pitch for a denser "small log" feel.
    function drawLog(dc, pad, y, w, h, rows, state) {
        var fnt = Gfx.FONT_XTINY;
        var lineH = dc.getFontHeight(fnt);
        if (lineH > 12) { lineH = lineH - 2; } // slightly compressed row height
        if (lineH < 9) { lineH = 9; }
        var maxLines = h / lineH;
        if (maxLines < 1) { maxLines = 1; }

        var start = 0;
        if (rows != null && rows.size() > maxLines) {
            start = rows.size() - maxLines;
        }
        var i = start;
        var ly = y;
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

    //! Live strip — two clear rows (no overlap with big SGV):
    //!   row1: SGV (left) + delta/age/mode (right)
    //!   row2: TGT | TBR | IOB | TIR
    function drawLiveStrip(dc, pad, y, w, h, sgvText, deltaNum, ageMin, mode, targetNum, tbr, iob, tir, state) {
        var stripTop = y;
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(pad, stripTop, pad + w, stripTop);

        var col = COL_HI;
        if (state == STATE_HYPO) { col = COL_RED; }
        else if (state == STATE_HYPER) { col = COL_AMBER; }

        var fnt = Gfx.FONT_XTINY;
        // MILD keeps the live digit readable without eating the metrics row
        var fontBg = Gfx.FONT_NUMBER_MILD;
        var bgH = dc.getFontHeight(fontBg);

        var row1Y = stripTop + 3;
        dc.setColor(col, Gfx.COLOR_TRANSPARENT);
        dc.drawText(pad, row1Y, fontBg, sgvText, Gfx.TEXT_JUSTIFY_LEFT);

        var tw = dc.getTextWidthInPixels(sgvText, fontBg);
        var metaX = pad + tw + 10;
        if (metaX > pad + w - 80) { metaX = pad + w / 2 + 10; }

        var dStr = "d--";
        if (deltaNum != null) {
            dStr = deltaNum > 0 ? ("d+" + deltaNum.toString()) : ("d" + deltaNum.toString());
        }
        var ageStr = "--";
        if (ageMin != null) { ageStr = ageMin.toString() + "m"; }
        dc.setColor(COL_MID, Gfx.COLOR_TRANSPARENT);
        dc.drawText(metaX, row1Y + 4, fnt, "-> " + dStr + " " + ageStr, Gfx.TEXT_JUSTIFY_LEFT);
        var modeStr = "mg/dL";
        if (mode != null && mode.equals("") == false) {
            modeStr = "mg/dL " + mode.toString();
        }
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(metaX, row1Y + 4 + dc.getFontHeight(fnt) + 1, fnt, modeStr, Gfx.TEXT_JUSTIFY_LEFT);

        // Metrics row — always below the SGV block
        var cellY = row1Y + bgH + 2;
        if (cellY + dc.getFontHeight(fnt) > stripTop + h - 2) {
            cellY = stripTop + h - dc.getFontHeight(fnt) - 2;
        }
        dc.setColor(COL_RULE, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(pad, cellY - 2, pad + w, cellY - 2);

        var cw = w / 4;
        var tgtV = "--";
        if (targetNum != null) { tgtV = targetNum.toString(); }
        var tbrV = compactTbr(tbr);
        var iobV = compactIob(iob);
        var tirV = "--";
        if (tir != null) { tirV = tir.toString() + "%"; }

        drawMetric(dc, pad, cellY, cw, fnt, "TGT", tgtV);
        drawMetric(dc, pad + cw, cellY, cw, fnt, "TBR", tbrV);
        drawMetric(dc, pad + 2 * cw, cellY, cw, fnt, "IOB", iobV);
        drawMetric(dc, pad + 3 * cw, cellY, cw, fnt, "TIR", tirV);
    }

    function drawMetric(dc, x, y, cw, fnt, label, value) {
        var labelW = dc.getTextWidthInPixels(label, fnt);
        dc.setColor(COL_DIM, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + 2, y, fnt, label, Gfx.TEXT_JUSTIFY_LEFT);
        dc.setColor(COL_MID, Gfx.COLOR_TRANSPARENT);
        var vx = x + 2 + labelW + 3;
        var v = value != null ? value : "--";
        // Truncate value if needed
        while (dc.getTextWidthInPixels(v, fnt) > cw - (vx - x) - 2 && v.length() > 2) {
            v = v.substring(0, v.length() - 1);
        }
        dc.drawText(vx, y, fnt, v, Gfx.TEXT_JUSTIFY_LEFT);
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
        // ms → sec
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

    //! Same magnitude rule as View.minutesFromTimestamp.
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
