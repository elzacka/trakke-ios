import Foundation

/// Høydemeter, regnet på én måte i hele appen.
///
/// Stigning og fall summeres mot et *anker* som bare flyttes når høyden har
/// endret seg mer enn `threshold`. Uten en slik terskel blir summen et mål på
/// støy: både GPS-høyde og høydedata fra karttjenester vingler et par meter
/// fra punkt til punkt, og med tusen punkter blir det hundrevis av falske
/// høydemeter. Terskelmetoden er også det andre turapper gjør, så tallet er
/// gjenkjennelig for folk som sammenligner.
///
/// Utregningen lå tidligere tre steder med tre ulike regler: opptaket brukte
/// anker, importerte turer summerte hver delta, og ruter gjorde det samme.
/// Samme fjell ga da ulike tall alt etter hvordan sporet kom inn i appen –
/// på en AllTrails-fil av Besseggen 1307 meter som rute mot 1209 som tur.
/// Nå er det denne ene kilden.
enum ElevationMath {
    /// Minste høydeendring som telles. Tre meter ligger over målestøyen i
    /// både barometer og GPS, og under det minste terrenget en tur faktisk
    /// merker.
    static let threshold: Double = 3

    /// Stigning og fall for en rekke høyder, der `nil` er punkter uten måling.
    /// Umålte punkter hoppes over uten å bryte kjeden – en tur med et hull i
    /// høydedataene skal ikke miste høydemeterne rundt hullet.
    static func gainLoss(altitudes: [Double?]) -> (gain: Double, loss: Double) {
        var gain: Double = 0
        var loss: Double = 0
        var anchor: Double?

        for case let altitude? in altitudes where altitude.isFinite {
            guard let previous = anchor else {
                anchor = altitude
                continue
            }
            let delta = altitude - previous
            guard abs(delta) > threshold else { continue }
            if delta > 0 {
                gain += delta
            } else {
                loss += abs(delta)
            }
            anchor = altitude
        }
        return (gain, loss)
    }
}
