import os

/// Unified logging. Read with:
/// `log show --last 10m --info --predicate 'subsystem == "app.hopclick.Hopclick"'`
/// or live with `log stream --level info --predicate 'subsystem == "app.hopclick.Hopclick"'`.
enum Log {
    private static let subsystem = "app.hopclick.Hopclick"
    static let click = Logger(subsystem: subsystem, category: "click")
    static let hover = Logger(subsystem: subsystem, category: "hover")
}
