using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.Time as Time;

//! CONCEPT — Téléscripteur (layoutStyle=10). AIMI green-phosphor journal.
module CGMWatchfaceTele {

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
        anzeigeTarget,
        anzeigeMode,
        anzeigeFehler,
        auswahlPfeil
    ) {
        AimicoDraw.hideClassicLabels(view);

        var width = dc.getWidth();
        var height = dc.getHeight();
        // Extra pad + bottom safe: Venu X1 rounded corners clip ~8–12 px
        var pad = 14;
        if (width < 400) { pad = 12; }
        var bottomSafe = 30;
        if (height < 400) { bottomSafe = 22; }

        var hyperProp = App.getApp().getProperty("hyperThreshold");
        var hyper = hyperProp != null ? hyperProp.toNumber() : 250;
        if (hyper == null) { hyper = 250; }

        var sgvMgdl = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["sgv"] != null) {
            sgvMgdl = punkte[0]["sgv"].toNumber();
        }
        var state = TeleDrawing.stateFromSgv(sgvMgdl, zielbereichLow, hyper);
        var deltaNum = deltaFromAaps(punkte, anzeigeDelta);
        var tir = tirFromAaps(punkte, zielbereichLow, zielbereichHigh);
        var targetNum = null;
        if (anzeigeTarget != null && anzeigeTarget.equals("") == false) {
            targetNum = anzeigeTarget.toNumber();
        }
        var ageMin = sanitizeAge(verzoegerung);
        var smbTs = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0) {
            smbTs = punkte[0]["smbHistory"];
        }

        var sgvText = "--";
        if (anzeigeSGV != null && anzeigeSGV.equals("") == false && anzeigeSGV.equals("--") == false) {
            sgvText = anzeigeSGV;
        }

        TeleDrawing.drawSheet(dc);
        var afterHeader = TeleDrawing.drawHeader(dc, pad, datum, timeString, steps, heartrate);

        var tinyH = dc.getFontHeight(Gfx.FONT_XTINY);
        // Live strip remonte (liveH 78 + bottomSafe 22) → comble le vide sous WAIT_
        var liveH = TeleDrawing.liveHeight(height);
        var liveY = height - bottomSafe - liveH;
        var logY = afterHeader;
        var logH = liveY - logY - 4;
        if (logH < 80) { logH = 80; }

        var rows = buildLogRows(smbTs, anzeigeMode, logH, TeleDrawing.logLineHeight(dc));
        rows.add({"kind" => TeleDrawing.KIND_SEP, "text" => "WAIT_"});

        TeleDrawing.drawLog(dc, pad, logY, width - 2 * pad, logH, rows, state);
        TeleDrawing.drawLiveStrip(
            dc, pad, liveY, width - 2 * pad, liveH,
            sgvText, deltaNum, ageMin, anzeigeMode,
            targetNum, anzeigeBasal, anzeigeIOB, tir, state
        );

        var err = AimicoDraw.friendlyError(anzeigeFehler);
        if (err.equals("") == false) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(width / 2, liveY - tinyH - 2, Gfx.FONT_XTINY, err, Gfx.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Chronological log: SGV + SMB (+ mode). No SESSION/SNAP — frees space; metrics live in footer.
    //! Cap rows so WAIT_ still fits: leave 1 line for WAIT (caller adds it).
    function buildLogRows(smbTs, mode, logH, lineH) {
        var events = [];
        var samples = collectSamples();
        var i = 0;
        while (i < samples.size()) {
            events.add({"t" => samples[i]["t"], "kind" => TeleDrawing.KIND_SGV, "sgv" => samples[i]["sgv"], "delta" => samples[i]["delta"]});
            i++;
        }

        if (smbTs != null && smbTs instanceof Lang.Array) {
            i = 0;
            while (i < smbTs.size()) {
                var item = smbTs[i];
                var sec = null;
                var units = null;
                if (item instanceof Lang.Dictionary) {
                    sec = TeleDrawing.toEpochSec(item["t"]);
                    if (item["u"] != null) { units = item["u"]; }
                } else {
                    sec = TeleDrawing.toEpochSec(item);
                }
                if (sec != null) {
                    events.add({"t" => sec, "kind" => TeleDrawing.KIND_SMB, "sgv" => null, "delta" => null, "u" => units});
                }
                i++;
            }
        }

        events = sortByTime(events);

        // Budget: logH can hold N lines; keep 1 for WAIT_ (+ optional MODE)
        var maxEvents = 5;
        if (lineH > 0 && logH > 0) {
            maxEvents = (logH / lineH) - 2; // WAIT + breathing room
            if (maxEvents < 4) { maxEvents = 4; }
            if (maxEvents > 7) { maxEvents = 7; } // one fewer line → room for live strip
        }
        if (events.size() > maxEvents) {
            var trimmed = [];
            var start = events.size() - maxEvents;
            i = start;
            while (i < events.size()) {
                trimmed.add(events[i]);
                i++;
            }
            events = trimmed;
        }

        var rows = [];
        i = 0;
        while (i < events.size()) {
            var ev = events[i];
            var hm = TeleDrawing.formatHm(ev["t"]);
            if (ev["kind"] == TeleDrawing.KIND_SGV) {
                var sgv = ev["sgv"];
                var dlt = ev["delta"];
                var dStr = "d--";
                if (dlt != null) {
                    dStr = dlt > 0 ? ("d+" + dlt.toString()) : ("d" + dlt.toString());
                }
                rows.add({"kind" => TeleDrawing.KIND_SGV, "text" => hm + " SGV " + pad3(sgv) + " " + dStr});
            } else if (ev["kind"] == TeleDrawing.KIND_SMB) {
                var smbLine = hm + " * SMB";
                if (ev["u"] != null) {
                    smbLine = smbLine + " " + formatSmbU(ev["u"]);
                } else {
                    smbLine = smbLine + " --U";
                }
                rows.add({"kind" => TeleDrawing.KIND_SMB, "text" => smbLine});
            }
            i++;
        }

        if (mode != null && mode.equals("") == false) {
            rows.add({
                "kind" => TeleDrawing.KIND_MODE,
                "text" => TeleDrawing.formatHm(Time.now().value()) + " * MODE " + mode.toString()
            });
        }

        return rows;
    }

    function collectSamples() {
        var out = [];
        // Prefer fresh AAPS batch (punkte) — bgReadingsAccumulated can freeze when
        // Float32 date compares stop seeing "newer" after a watch firmware update.
        var src = null;
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 1) {
            src = punkte;
        } else if (bgReadingsAccumulated != null && bgReadingsAccumulated instanceof Lang.Array) {
            src = bgReadingsAccumulated;
        }
        if (src != null) {
            var n = src.size();
            var start = 0;
            if (n > 24) { start = n - 24; }
            var i = n - 1;
            while (i >= start) {
                var pt = src[i];
                if (pt != null && pt["sgv"] != null && pt["date"] != null) {
                    var v = pt["sgv"].toNumber();
                    var sec = TeleDrawing.toEpochSec(pt["date"]);
                    if (v != null && v >= 20 && v <= 600 && sec != null) {
                        var dlt = null;
                        if (pt["delta"] != null) { dlt = pt["delta"].toNumber(); }
                        out.add({"t" => sec, "sgv" => v, "delta" => dlt});
                    }
                }
                i--;
            }
        }
        out = sortSamples(out);
        // Derive 5-min deltas from consecutive samples when AAPS didn't attach them
        var j = 1;
        while (j < out.size()) {
            if (out[j]["delta"] == null && out[j - 1]["sgv"] != null && out[j]["sgv"] != null) {
                var dt = out[j]["t"] - out[j - 1]["t"];
                if (dt > 0) {
                    var raw = (out[j]["sgv"] - out[j - 1]["sgv"]).toFloat();
                    // Normalize to ~5 min window (Nightscout convention)
                    var d5 = (raw / dt.toFloat()) * 300.0;
                    out[j]["delta"] = d5.toNumber();
                }
            }
            j++;
        }
        return out;
    }

    function sortSamples(arr) {
        var n = arr.size();
        var a = 1;
        while (a < n) {
            var key = arr[a];
            var b = a - 1;
            while (b >= 0 && arr[b]["t"] > key["t"]) {
                arr[b + 1] = arr[b];
                b--;
            }
            arr[b + 1] = key;
            a++;
        }
        return arr;
    }

    function sortByTime(arr) {
        var n = arr.size();
        var a = 1;
        while (a < n) {
            var key = arr[a];
            var b = a - 1;
            while (b >= 0 && arr[b]["t"] > key["t"]) {
                arr[b + 1] = arr[b];
                b--;
            }
            arr[b + 1] = key;
            a++;
        }
        return arr;
    }

    function pad3(n) {
        if (n == null) { return "---"; }
        var s = n.toString();
        if (s.length() == 1) { return "  " + s; }
        if (s.length() == 2) { return " " + s; }
        return s;
    }

    //! Format SMB units for the log, e.g. 0.35 -> "0.35U"
    function formatSmbU(u) {
        if (u == null) { return ""; }
        var n = u.toFloat();
        if (n == null) {
            return u.toString() + "U";
        }
        // One or two decimals without trailing noise
        var cent = (n * 100.0 + 0.5).toNumber();
        if (cent == null) { return n.toString() + "U"; }
        var whole = cent / 100;
        var frac = cent - whole * 100;
        if (frac < 0) { frac = -frac; }
        if (frac == 0) {
            return whole.toString() + "U";
        }
        if (frac < 10) {
            return whole.toString() + ".0" + frac.toString() + "U";
        }
        return whole.toString() + "." + frac.toString() + "U";
    }

    function deltaFromAaps(punkte, anzeigeDelta) {
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["delta"] != null) {
            var raw = punkte[0]["delta"].toNumber();
            if (raw != null) { return raw; }
        }
        if (anzeigeDelta == null || anzeigeDelta.equals("") || anzeigeDelta.equals("--")) { return 0; }
        var s = anzeigeDelta.toString();
        if (s.length() > 0 && s.substring(0, 1).equals("+")) {
            s = s.substring(1, s.length());
        }
        var n = s.toNumber();
        if (n == null) { return 0; }
        return n;
    }

    //! Prefer AAPS `tir`; fall back to local % of accumulated samples in [low, high].
    function tirFromAaps(punkte, low, high) {
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["tir"] != null) {
            var t = punkte[0]["tir"].toNumber();
            if (t != null) {
                if (t < 0) { t = 0; }
                if (t > 100) { t = 100; }
                return t;
            }
        }
        return calcTirLocal(low, high);
    }

    function calcTirLocal(low, high) {
        var samples = collectSamples();
        if (samples == null || samples.size() == 0) { return null; }
        var lo = low != null ? low.toNumber() : 70;
        var hi = high != null ? high.toNumber() : 180;
        if (lo == null) { lo = 70; }
        if (hi == null) { hi = 180; }
        if (lo > hi) {
            var tmp = lo;
            lo = hi;
            hi = tmp;
        }
        var inRange = 0;
        var i = 0;
        while (i < samples.size()) {
            var v = samples[i]["sgv"];
            if (v != null && v >= lo && v <= hi) { inRange++; }
            i++;
        }
        return ((inRange * 100) / samples.size()).toNumber();
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

}
