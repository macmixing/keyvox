/// The spoken names of punctuation marks a speaker says to write the mark, each as its lowercase
/// words.
enum SpokenCommand {
    static let questionMark = ["question", "mark"]
    static let exclamationPoint = ["exclamation", "point"]
    static let exclamationMark = ["exclamation", "mark"]
    static let period = ["period"]
    static let fullStop = ["full", "stop"]
    static let comma = ["comma"]

    static let all = [questionMark, exclamationPoint, exclamationMark, period, fullStop, comma]
}
