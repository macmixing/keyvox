extension KeyboardViewController {
    func synchronizeTypingKeyPresentation() {
        rootContainerView?.keyGridView.setSymbolPage(symbolPage)
        rootContainerView?.keyGridView.setLetterCase(letterCaseController.letterCase)
    }
}
