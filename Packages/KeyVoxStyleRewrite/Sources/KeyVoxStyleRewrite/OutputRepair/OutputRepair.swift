import Foundation

enum OutputRepair {
    static func repairDeletedSeparatorPunctuation(original: String, rewritten: String) -> String {
        let punctuationRepaired = PunctuationRepair().repair(original: original, rewritten: rewritten)
        let addressRepaired = AddressFactRepair().repair(original: original, rewritten: punctuationRepaired)
        let moneyRepaired = MoneyFactRepair().repair(original: original, rewritten: addressRepaired)
        let deletedNumberRepaired = DeletedNumberEvidenceRepair().repair(original: original, rewritten: moneyRepaired)
        return APStyleNumberRepair().repair(original: original, rewritten: deletedNumberRepaired)
    }
}
