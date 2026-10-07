import Foundation

/// Whether this process is an `xcodebuild test` host rather than a Codenotch
/// somebody launched.
///
/// The unit bundle is hosted by the app itself, so a test run *is* a running
/// Codenotch — and anything that would reach outside the process has to ask
/// first. Without the check every test run put a live request on the usage
/// endpoint, and every `NotchWindowController` a test constructed ordered a
/// real panel onto the developer's screen: a single `make test` put forty of
/// them up at once, over whatever was being worked on, for the half minute the
/// suite took.
enum Runtime {
    static var isQABundle: Bool {
        Bundle.main.object(forInfoDictionaryKey: "CodenotchQAMode") as? Bool == true
    }
    static var isForkBuild: Bool {
        #if CODENOTCH_FORK
        true
        #else
        Bundle.main.object(forInfoDictionaryKey: "CodenotchForkBuild") as? Bool == true
        #endif
    }
    static var updatesEnabled: Bool { !isQABundle && !isForkBuild }
    static let isUnderTest: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
}
