using Toybox.WatchUi as Ui;

//! AIMICO V1 mascot / arrow selection (E1 layout).
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

    //! Map Classic trend string → AIMICO arrow drawable resource.
    function arrowDrawable(auswahlPfeil) {
        if (auswahlPfeil == null) {
            return Ui.loadResource(Rez.Drawables.AimicoArrowNone);
        }
        if (auswahlPfeil.equals("DoubleDown")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrowDoubleDown);
        } else if (auswahlPfeil.equals("SingleDown")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrowSingleDown);
        } else if (auswahlPfeil.equals("FortyFiveDown")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrow45Down);
        } else if (auswahlPfeil.equals("Flat")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrowFlat);
        } else if (auswahlPfeil.equals("FortyFiveUp")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrow45Up);
        } else if (auswahlPfeil.equals("SingleUp")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrowSingleUp);
        } else if (auswahlPfeil.equals("DoubleUp")) {
            return Ui.loadResource(Rez.Drawables.AimicoArrowDoubleUp);
        }
        return Ui.loadResource(Rez.Drawables.AimicoArrowNone);
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
