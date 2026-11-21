import AudioToolbox
import CoreAudioKit
import UIKit

/// The extension's entry point. The Audio Unit shows no interface; the UI kind of Audio Unit
/// extension is used because it runs without the plain kind's memory ceiling.
final class TranscriptionAUViewController: AUViewController, AUAudioUnitFactory {
    override func loadView() {
        view = UIView()
    }

    func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        try TranscriptionAU(componentDescription: componentDescription)
    }
}
