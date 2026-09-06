import Foundation
import LocalStackCore

@main
struct LocalStackCoordinatorMain {
    static func main() async {
        let coordinator = LocalStackCoordinator()
        let socket = UnixJSONRPCServer()
        do {
            let service = CoordinatorRPCService(coordinator: coordinator, socketPath: UnixJSONRPCServer.defaultSocketPath())
            try socket.start { request in await service.handle(request) }
        } catch {
            fputs("LocalStackCoordinator failed to start: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        await coordinator.boot()
        await coordinator.start()

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(86_400))
        }
        socket.stop()
        await coordinator.stop()
    }
}
