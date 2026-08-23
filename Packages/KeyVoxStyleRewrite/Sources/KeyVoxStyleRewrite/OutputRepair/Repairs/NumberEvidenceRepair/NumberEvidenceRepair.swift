import Foundation

struct NumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let versionRepaired = VersionNumberEvidenceRepair().repair(original: original, rewritten: rewritten)
        let decimalRepaired = DecimalNumberEvidenceRepair().repair(original: original, rewritten: versionRepaired)
        let unsupportedCurrencyRepaired = UnsupportedCurrencyEvidenceRepair().repair(
            original: original,
            rewritten: decimalRepaired
        )
        let changedNumberRepaired = ChangedNumberEvidenceRepair().repair(
            original: original,
            rewritten: unsupportedCurrencyRepaired
        )
        let insertedNumberRepaired = InsertedNumberEvidenceRepair().repair(original: original, rewritten: changedNumberRepaired)
        let deletedNumberRepaired = DeletedNumberEvidenceRepair().repair(original: original, rewritten: insertedNumberRepaired)
        return NumberSeparatorEvidenceRepair().repair(original: original, rewritten: deletedNumberRepaired)
    }
}
