import Foundation

/// Abstraction over a crash-reporting backend (e.g. Crashlytics later).
protocol CrashReporter {
    func record(_ error: Error)
    func log(_ message: String)
}

struct NoOpCrashReporter: CrashReporter {
    func record(_ error: Error) {}
    func log(_ message: String) {}
}
