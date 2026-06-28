import Foundation

public final class HotKeyCoordinator<Registrar: HotKeyRegistering> {
    private let registrar: Registrar
    private let perform: @Sendable (WindowAction, WindowCommandOptions) -> WindowCommandResult
    private let recognizer = HotKeySequenceRecognizer()

    public init(
        registrar: Registrar,
        perform: @escaping @Sendable (WindowAction, WindowCommandOptions) -> WindowCommandResult
    ) {
        self.registrar = registrar
        self.perform = perform
    }

    public func start() throws {
        try registrar.register(HotKeyMapping.defaultHotKeys) { [perform, recognizer] hotKey in
            let now = Date().timeIntervalSinceReferenceDate
            guard let action = recognizer.action(for: hotKey, at: now) else {
                return
            }

            _ = perform(
                action,
                WindowCommandOptions(screenTarget: HotKeyMapping.screenTarget(for: hotKey))
            )
        }
    }

    public func stop() {
        registrar.unregisterAll()
    }
}
