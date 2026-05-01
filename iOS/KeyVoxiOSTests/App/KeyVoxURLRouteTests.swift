import Foundation
import Testing
@testable import KeyVox_iOS

struct KeyVoxURLRouteTests {
    @Test func parsesStartRecordingRoute() {
        let route = KeyVoxURLRoute(url: URL(string: "keyvoxios://record/start")!)
        #expect(route == .startRecording)
    }

    @Test func parsesStopRecordingRoute() {
        let route = KeyVoxURLRoute(url: URL(string: "keyvoxios://record/stop")!)
        #expect(route == .stopRecording)
    }

    @Test func parsesOpenDictionaryRoute() {
        let route = KeyVoxURLRoute(url: URL(string: "keyvoxios://tab/dictionary")!)
        #expect(route == .openDictionary)
    }

    @Test func parsesOpenSettingsRoute() {
        let route = KeyVoxURLRoute(url: URL(string: "keyvoxios://tab/settings")!)
        #expect(route == .openSettings)
    }

    @Test func rejectsInvalidScheme() {
        let route = KeyVoxURLRoute(url: URL(string: "https://record/start")!)
        #expect(route == nil)
    }

    @Test func rejectsInvalidHostOrPath() {
        #expect(KeyVoxURLRoute(url: URL(string: "keyvoxios://other/start")!) == nil)
        #expect(KeyVoxURLRoute(url: URL(string: "keyvoxios://record/nope")!) == nil)
    }
}
