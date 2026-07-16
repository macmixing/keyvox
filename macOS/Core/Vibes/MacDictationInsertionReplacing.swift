protocol MacDictationInsertionReplacing: AnyObject {
    func currentTextMatchesUntouchedInsertion(_ text: String) -> Bool
    func replaceUntouchedInsertion(_ currentText: String, with replacementText: String) -> Bool
}

extension PasteService: MacDictationInsertionReplacing {}
