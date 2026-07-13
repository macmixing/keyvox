import Foundation

actor OutputRepairExecutor {
    func repairModelOutput(original: String, rewritten: String) -> String {
        OutputRepair.repairModelOutput(original: original, rewritten: rewritten)
    }
}

enum OutputRepair {
    static func repairModelOutput(original: String, rewritten: String) -> String {
        let punctuationRepaired = PunctuationRepair().repair(original: original, rewritten: rewritten)
        let terminalPunctuationRepaired = TerminalPunctuationBoundaryRepair().repair(
            original: original,
            rewritten: punctuationRepaired
        )
        let addressRepaired = AddressFactRepair().repair(original: original, rewritten: terminalPunctuationRepaired)
        let moneyRepaired = MoneyFactRepair().repair(original: original, rewritten: addressRepaired)
        let numberEvidenceRepaired = NumberEvidenceRepair().repair(original: original, rewritten: moneyRepaired)
        let apStyleRepaired = APStyleNumberRepair().repair(original: original, rewritten: numberEvidenceRepaired)
        return apStyleRepaired
    }
}
