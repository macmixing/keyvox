import CompositionVerification

@main
struct CompositionProbe {
    static func main() throws {
        try CompositionVerification.verify()
        print("Composition checks passed")
    }
}
