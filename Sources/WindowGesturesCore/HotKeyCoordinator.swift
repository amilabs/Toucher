import Foundation

public final class HotKeyCoordinator<Registrar: HotKeyRegistering> {
    private let registrar: Registrar
    private let perform: @Sendable (WindowAction) -> WindowCommandResult

    public init(
        registrar: Registrar,
        perform: @escaping @Sendable (WindowAction) -> WindowCommandResult
    ) {
        self.registrar = registrar
        self.perform = perform
    }

    public func start() throws {
        try registrar.register(HotKeyMapping.defaultHotKeys) { [perform] hotKey in
            guard let action = HotKeyMapping.action(for: hotKey) else {
                return
            }

            _ = perform(action)
        }
    }

    public func stop() {
        registrar.unregisterAll()
    }
}
