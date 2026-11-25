import XCTest

/// One finger drawn along a path of screen points, for gestures `XCUICoordinate` cannot make,
/// such as a swipe through several keys. Uses XCTest's event synthesis (`XCPointerEventPath` and
/// `XCSynthesizedEventRecord`), which the simulator and devices run as real touches.
enum SyntheticTouchPath {
    enum SynthesisError: Error {
        case unavailable(String)
        case failed(Error?)
    }

    private typealias InitPath = @convention(c) (AnyObject, Selector, CGPoint, Double) -> AnyObject
    private typealias Move = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Void
    private typealias Lift = @convention(c) (AnyObject, Selector, Double) -> Void
    private typealias InitRecord = @convention(c) (AnyObject, Selector, NSString, Int) -> AnyObject
    private typealias AddPath = @convention(c) (AnyObject, Selector, AnyObject) -> Void
    private typealias Synthesize = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> Bool

    /// Lands at `samples[0].point`, moves through every later sample at its time offset in
    /// seconds, lifts at the last, and returns once the gesture has played.
    static func perform(_ samples: [(point: CGPoint, offset: TimeInterval)]) throws {
        guard let first = samples.first else { return }
        let path = try make("XCPointerEventPath", "initForTouchAtPoint:offset:") { (initializer: InitPath, object, selector) in
            initializer(object, selector, first.point, first.offset)
        }
        let move: Move = try method(of: path, "moveToPoint:atOffset:")
        for sample in samples.dropFirst() {
            move(path, NSSelectorFromString("moveToPoint:atOffset:"), sample.point, sample.offset)
        }
        let lift: Lift = try method(of: path, "liftUpAtOffset:")
        lift(path, NSSelectorFromString("liftUpAtOffset:"), samples[samples.count - 1].offset)
        let record = try make("XCSynthesizedEventRecord", "initWithName:interfaceOrientation:") { (initializer: InitRecord, object, selector) in
            initializer(object, selector, "swipe" as NSString, UIInterfaceOrientation.portrait.rawValue)
        }
        let add: AddPath = try method(of: record, "addPointerEventPath:")
        add(record, NSSelectorFromString("addPointerEventPath:"), path)
        let synthesize: Synthesize = try method(of: record, "synthesizeWithError:")
        var error: NSError?
        guard synthesize(record, NSSelectorFromString("synthesizeWithError:"), &error) else {
            throw SynthesisError.failed(error)
        }
    }

    private static func make<Initializer>(
        _ className: String,
        _ selectorName: String,
        _ call: (Initializer, AnyObject, Selector) -> AnyObject
    ) throws -> AnyObject {
        guard let type = NSClassFromString(className) as? NSObject.Type else {
            throw SynthesisError.unavailable(className)
        }
        let object = type.perform(NSSelectorFromString("alloc")).takeUnretainedValue()
        let initializer: Initializer = try method(of: object, selectorName)
        return call(initializer, object, NSSelectorFromString(selectorName))
    }

    private static func method<Function>(of object: AnyObject, _ selectorName: String) throws -> Function {
        let selector = NSSelectorFromString(selectorName)
        guard let object = object as? NSObject, object.responds(to: selector) else {
            throw SynthesisError.unavailable(selectorName)
        }
        return unsafeBitCast(object.method(for: selector), to: Function.self)
    }
}
