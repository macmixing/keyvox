protocol MacDictationInsertionReplacing: AnyObject {
    func currentTextMatchesUntouchedInsertion(_ text: String) async -> Bool
    func replaceUntouchedInsertion(_ currentText: String, with replacementText: String) async -> Bool
}

extension PasteService: MacDictationInsertionReplacing {}
