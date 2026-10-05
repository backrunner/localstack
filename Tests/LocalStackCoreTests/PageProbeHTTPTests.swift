import Foundation
import Darwin
import Testing
import LocalStackShared
@testable import LocalStackCore

private final class ProbeHTTPFixture {
    let process = Process()
    let port: Int

    init() throws {
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-u", "-c", """
            import json, socket, time
            from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
            from urllib.parse import urlparse, parse_qs
            stats = {'visited': 0, 'cancelled': 0}
            class Handler(BaseHTTPRequestHandler):
                def do_GET(self):
                    url = urlparse(self.path)
                    if url.path == '/stats':
                        self.send_response(200); self.end_headers()
                        self.wfile.write(json.dumps(stats).encode()); return
                    if url.path == '/outside':
                        self.send_response(302)
                        self.send_header('Location', parse_qs(url.query)['to'][0])
                        self.end_headers(); return
                    if url.path.startswith('/redirect/'):
                        count = int(url.path.rsplit('/', 1)[1])
                        self.send_response(302)
                        self.send_header('Location', '/html' if count == 1 else '/redirect/' + str(count - 1))
                        self.end_headers(); return
                    if url.path == '/oversized':
                        self.send_response(200)
                        self.send_header('Content-Type', 'text/html')
                        self.send_header('Content-Length', '1048576')
                        self.end_headers()
                        self.wfile.write(b'<'); self.wfile.flush()
                        self.connection.settimeout(2)
                        try:
                            if self.connection.recv(1) == b'': stats['cancelled'] += 1
                        except (ConnectionResetError, BrokenPipeError): stats['cancelled'] += 1
                        except socket.timeout: pass
                        return
                    if url.path == '/slow': time.sleep(1)
                    if url.path in ['/html', '/visited', '/slow']:
                        if url.path == '/visited': stats['visited'] += 1
                        body = b'<html><title>Fixture</title></html>'
                        self.send_response(200)
                        self.send_header('Content-Type', 'text/html')
                        self.send_header('Content-Length', str(len(body)))
                        self.end_headers()
                        try: self.wfile.write(body)
                        except (BrokenPipeError, ConnectionResetError): pass
                        return
                    self.send_response(404); self.end_headers()
                def log_message(self, *args): pass
            server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            print(server.server_port, flush=True)
            server.serve_forever()
            """]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let value = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        port = try #require(Int(value))
    }

    func stop() {
        // Foundation's waitUntilExit can wait on a run loop from a different
        // Swift executor after an await. Reap this owned fixture with POSIX and
        // a deadline instead of letting test cleanup hang indefinitely.
        let pid = process.processIdentifier
        var status: Int32 = 0
        guard waitpid(pid, &status, WNOHANG) == 0 else { return }
        kill(pid, SIGTERM)
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if waitpid(pid, &status, WNOHANG) != 0 { return }
            usleep(10_000)
        }
        kill(pid, SIGKILL)
        if waitpid(pid, &status, 0) < 0 && errno != ECHILD {
            Issue.record("could not reap HTTP fixture")
        }
    }

    func url(_ path: String) -> URL { URL(string: "http://127.0.0.1:\(port)\(path)")! }

    func redirect(to target: URL) -> URL {
        var components = URLComponents(url: url("/outside"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "to", value: target.absoluteString)]
        return components.url!
    }

    func stats() async throws -> [String: Int] {
        let (data, _) = try await URLSession.shared.data(from: url("/stats"))
        return try JSONDecoder().decode([String: Int].self, from: data)
    }
}

@Suite(.serialized)
struct PageProbeHTTPTests {
    @Test("HTML is accepted and same-origin redirects are limited to three")
    func htmlAndRedirectLimit() async throws {
        let server = try ProbeHTTPFixture()
        defer { server.stop() }
        let probe = PageProbe()
        #expect(try await probe.probe(server.url("/html")).evidence.title == "Fixture")
        #expect(try await probe.probe(server.url("/redirect/3")).evidence.finalURL == server.url("/html"))
        do {
            _ = try await probe.probe(server.url("/redirect/4"))
            Issue.record("redirect limit was ignored")
        } catch let error as CoordinatorError { #expect(error.code == .pageUnavailable) }
    }

    @Test("redirect targets are rejected before contacting a different listener or host")
    func redirectCannotContactAnotherOrigin() async throws {
        let source = try ProbeHTTPFixture()
        let target = try ProbeHTTPFixture()
        defer { source.stop(); target.stop() }
        let probe = PageProbe()
        let destinations = [target.url("/visited"),
                            URL(string: "http://localhost:\(source.port)/visited")!,
                            URL(string: "http://user:password@127.0.0.1:\(source.port)/visited")!,
                            URL(string: "https://127.0.0.1:\(source.port)/visited")!]
        for destination in destinations {
            do {
                _ = try await probe.probe(source.redirect(to: destination))
                Issue.record("redirect escaped its origin")
            } catch let error as CoordinatorError { #expect(error.code == .outsideLoopback) }
        }
        #expect(try await target.stats()["visited"] == 0)
        #expect(try await source.stats()["visited"] == 0)
    }

    @Test("an oversized body is cancelled immediately instead of lingering until timeout")
    func oversizedResponseClosesConnection() async throws {
        let server = try ProbeHTTPFixture()
        defer { server.stop() }
        do {
            _ = try await PageProbe(timeout: 5, maximumResponseBytes: 1024).probe(server.url("/oversized"))
            Issue.record("oversized response was accepted")
        } catch let error as CoordinatorError { #expect(error.code == .pageUnavailable) }
        for _ in 0..<10 {
            if try await server.stats()["cancelled"] == 1 { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("abandoned response connection was not cancelled")
    }

    @Test("slow listeners time out and caller cancellation stops a pending probe")
    func timeoutAndCancellation() async throws {
        let server = try ProbeHTTPFixture()
        defer { server.stop() }
        let start = ContinuousClock.now
        do {
            _ = try await PageProbe(timeout: 0.1).probe(server.url("/slow"))
            Issue.record("slow request did not time out")
        } catch let error as CoordinatorError { #expect(error.code == .pageUnavailable) }
        #expect(start.duration(to: .now) < .seconds(1))
        let slowURL = server.url("/slow")
        let pending = Task { try await PageProbe(timeout: 5).probe(slowURL) }
        try await Task.sleep(for: .milliseconds(50))
        let cancelledAt = ContinuousClock.now
        pending.cancel()
        do {
            _ = try await pending.value
            Issue.record("cancelled probe succeeded")
        } catch {}
        #expect(cancelledAt.duration(to: .now) < .seconds(1))
    }
}
