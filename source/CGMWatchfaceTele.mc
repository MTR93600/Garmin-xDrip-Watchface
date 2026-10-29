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
        var pad = 12;
        if (width < 400) { pad = 10; }

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
        var afterHeader = TeleDrawing.drawHeader(dc, pad, datum, timeString);

        var tinyH = dc.getFontHeight(Gfx.FONT_XTINY);
        var liveH = 68;
        if (height < 400) { liveH = 60; }
        var liveY = height - pad - liveH;
        var logY = afterHeader;
        var logH = liveY - logY - 4;
        if (logH < 80) { logH = 80; }

        var rows = buildLogRows(
            punkte, smbTs, anzeigeMode, anzeigeIOB, targetNum, anzeigeBasal, tir, deltaNum
        );
        // Trailing WAIT cursor line
        rows.add({:kind => TeleDrawing.KIND_SEP, :text => "WAIT_"});

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

    //! Merge SGV samples + SMB + mode + snapshot into chronological log rows (oldest→newest).
    function buildLogRows(punkte, smbTs, mode, iob, targetNum, basal, tir, deltaNum) {
        var events = []; // { :t, :kind, :payload }

        // SGV from accumulated buffer (oldest→newest)
        var samples = collectSamples();
        var i = 0;
        while (i < samples.size()) {
            events.add({:t => samples[i][:t], :kind => TeleDrawing.KIND_SGV, :payload => samples[i]});
            i++;
        }

        // SMB timestamps
        if (smbTs != null && smbTs instanceof Lang.Array) {
            i = 0;
            while (i < smbTs.size()) {
                var sec = TeleDrawing.toEpochSec(smbTs[i]);
                if (sec != null) {
                    events.add({:t => sec, :kind => TeleDrawing.KIND_SMB, :payload => null});
                }
                i++;
            }
        }

        // Sort by time ascending (simple insertion — n is small)
        events = sortByTime(events);

        // Cap samples so log stays readable (~18 events before mode/snap)
        if (events.size() > 16) {
            var trimmed = [];
            var start = events.size() - 16;
            i = start;
            while (i < events.size()) {
                trimmed.add(events[i]);
                i++;
            }
            events = trimmed;
        }

        var rows = [];
        rows.add({:kind => TeleDrawing.KIND_SEP, :text => "── SESSION ────────────────"});

        var lastIob = compactIob(iob);
        i = 0;
        while (i < events.size()) {
            var ev = events[i];
            var hm = TeleDrawing.formatHm(ev[:t]);
            if (ev[:kind] == TeleDrawing.KIND_SGV) {
                var p = ev[:payload];
                var sgv = p[:sgv];
                var dlt = p[:delta];
                var dStr = "d--";
                if (dlt != null) {
                    dStr = dlt > 0 ? ("d+" + dlt.toString()) : ("d" + dlt.toString());
                }
                var line = hm + "  SGV  " + pad3(sgv) + "  " + dStr + "  IOB " + lastIob;
                rows.add({:kind => TeleDrawing.KIND_SGV, :text => line});
            } else if (ev[:kind] == TeleDrawing.KIND_SMB) {
                rows.add({:kind => TeleDrawing.KIND_SMB, :text => hm + "  * SMB"});
            }
            i++;
        }

        // Mode annotation (current only — no history)
        if (mode != null && mode.equals("") == false) {
            rows.add({
                :kind => TeleDrawing.KIND_MODE,
                :text => TeleDrawing.formatHm(Time.now().value()) + "  * MODE " + mode.toString()
            });
        }

        // System snapshot
        var snap = TeleDrawing.formatHm(Time.now().value()) + "  ";
        var tgt = "--";
        if (targetNum != null) { tgt = targetNum.toString(); }
        var tbr = TeleDrawing.compactTbr(basal);
        var tirV = "--";
        if (tir != null) { tirV = tir.toString() + "%"; }
        snap = snap + "TGT " + tgt + "  TBR " + tbr + "  TIR " + tirV;
        rows.add({:kind => TeleDrawing.KIND_SNAP, :text => snap});

        return rows;
    }

    function collectSamples() {
        var out = [];
        if (bgReadingsAccumulated != null && bgReadingsAccumulated instanceof Lang.Array) {
            var n = bgReadingsAccumulated.size();
            var start = 0;
            if (n > 24) { start = n - 24; }
            // accumulated is newest-first typically after merge — walk reverse to oldest→newest
            var i = n - 1;
            while (i >= start) {
                var pt = bgReadingsAccumulated[i];
                if (pt != null && pt["sgv"] != null && pt["date"] != null) {
                    var v = pt["sgv"].toNumber();
                    var sec = TeleDrawing.toEpochSec(pt["date"]);
                    if (v != null && v >= 20 && v <= 600 && sec != null) {
                        var dlt = null;
                        if (pt["delta"] != null) { dlt = pt["delta"].toNumber(); }
                        out.add({:t => sec, :sgv => v, :delta => dlt});
                    }
                }
                i--;
            }
        }
        // If still empty / reversed wrong, try punkte newest-first → reverse
        if (out.size() < 2) {
            // keep what we have
        }
        // Ensure chronological oldest→newest by time
        out = sortSamples(out);
        return out;
    }

    function sortSamples(arr) {
        var n = arr.size();
        var a = 1;
        while (a < n) {
            var key = arr[a];
            var b = a - 1;
            while (b >= 0 && arr[b][:t] > key[:t]) {
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
            while (b >= 0 && arr[b][:t] > key[:t]) {
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

    function compactIob(iob) {
        return TeleDrawing.compactIob(iob);
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

    function tirFromAaps(punkte, low, high) {
        if (punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 && punkte[0]["tir"] != null) {
            var t = punkte[0]["tir"].toNumber();
            if (t != null) {
                if (t < 0) { t = 0; }
                if (t > 100) { t = 100; }
                return t;
            }
        }
        return null;
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
