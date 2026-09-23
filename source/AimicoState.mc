using Toybox.WatchUi as Ui;

//! AIMICO V2 mascot / arrow selection (E1 layout).
//! Pure helpers — no HTTP side effects.
module AimicoState {

    //! Returns "low" | "inrange" | "high" | "none"
    function mascotKind(sgvMgdl, lowMgdl, highMgdl) {
        if (sgvMgdl == null) {
            return "none";
        }
        var v = sgvMgdl.toNumber();
        if (v == null) {
            return "none";
        }
        var lo = lowMgdl != null ? lowMgdl.toNumber() : 70;
        var hi = highMgdl != null ? highMgdl.toNumber() : 180;
        if (lo == null) { lo = 70; }
        if (hi == null) { hi = 180; }
        if (v < lo) {
            return "low";
        } else if (v > hi) {
            return "high";
        }
        return "inrange";
    }

    //! Classic trend arrow bitmaps (clean, scale well).
    function classicArrowDrawable(auswahlPfeil) {
        if (auswahlPfeil == null) {
            return null;
        }
        if (auswahlPfeil.equals("DoubleDown")) {
            return Ui.loadResource(Rez.Drawables.id_1);
        } else if (auswahlPfeil.equals("SingleDown")) {
            return Ui.loadResource(Rez.Drawables.id_2);
        } else if (auswahlPfeil.equals("FortyFiveDown")) {
            return Ui.loadResource(Rez.Drawables.id_3);
        } else if (auswahlPfeil.equals("Flat")) {
            return Ui.loadResource(Rez.Drawables.id_4);
        } else if (auswahlPfeil.equals("FortyFiveUp")) {
            return Ui.loadResource(Rez.Drawables.id_5);
        } else if (auswahlPfeil.equals("SingleUp")) {
            return Ui.loadResource(Rez.Drawables.id_6);
        } else if (auswahlPfeil.equals("DoubleUp")) {
            return Ui.loadResource(Rez.Drawables.id_7);
        }
        return null;
    }

    function mascotDrawable(kind) {
        if (kind.equals("low")) {
            return Ui.loadResource(Rez.Drawables.MascotLow);
        } else if (kind.equals("high")) {
            return Ui.loadResource(Rez.Drawables.MascotHigh);
        } else if (kind.equals("inrange")) {
            return Ui.loadResource(Rez.Drawables.MascotInRange);
        }
        return null;
    }

}
