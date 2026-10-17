import test from "node:test";
import assert from "node:assert/strict";
import net from "node:net";
import { EventEmitter, once } from "node:events";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { register, heartbeat, unregister, localStack } from "../dist/index.js";

async function coordinatorFixture(t, respond) {
  const directory = await mkdtemp(join(tmpdir(), "ls-sdk-"));
  const path = join(directory, "rpc.sock");
  const requests = [];
  const server = net.createServer(socket => {
    let input = "";
    socket.on("data", chunk => {
      input += chunk.toString();
      if (!input.includes("\n")) return;
      const request = JSON.parse(input.split("\n")[0]);
      requests.push(request);
      socket.end(JSON.stringify({ id: request.id, ...respond(request) }) + "\n");
    });
  });
  server.listen(path);
  await once(server, "listening");
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    await rm(directory, { recursive: true, force: true });
  });
  return { path, requests };
}

const lease = (id = "registration-1") => ({
  service: { id: "service-1" }, registrationID: id,
  leaseToken: "test-token", leaseExpiresAt: "2030-01-01T00:00:00Z"
});

async function until(predicate) {
  const deadline = Date.now() + 3000;
  while (!predicate()) {
    assert.ok(Date.now() < deadline, "lifecycle did not converge within 3 seconds");
    await new Promise(resolve => setTimeout(resolve, 10));
  }
}

test("SDK lifecycle uses real Unix sockets and preserves lease credentials", async t => {
  const fixture = await coordinatorFixture(t, request => ({ result:
    request.method === "service.register" ? lease() :
      request.method === "service.heartbeat" ? { expiresAt: "2030-01-01T00:00:00Z" } : { ok: true }
  }));
  const result = await register({ port: 4173, displayName: "SDK fixture", coordinatorSocket: fixture.path });
  await heartbeat(result, fixture.path);
  await unregister(result, fixture.path);
  assert.deepEqual(fixture.requests.map(request => request.method), ["service.register", "service.heartbeat", "service.unregister"]);
  assert.equal(fixture.requests[0].params.pid, process.pid);
  assert.equal(fixture.requests[0].params.source, "sdk");
  assert.equal(fixture.requests[0].params.displayName, "SDK fixture");
  for (const request of fixture.requests.slice(1)) {
    assert.deepEqual(request.params, { registrationID: "registration-1", leaseToken: "test-token" });
  }
});

test("Vite renews, re-registers after a lost lease, and unregisters the current lease on close", async t => {
  let registrations = 0;
  const fixture = await coordinatorFixture(t, request => {
    if (request.method === "service.register") return { result: lease(`registration-${++registrations}`) };
    if (request.method === "service.heartbeat" && request.params.registrationID === "registration-1") {
      return { error: { code: "notFound", message: "Coordinator restarted" } };
    }
    return { result: { ok: true, expiresAt: "2030-01-01T00:00:00Z" } };
  });
  const httpServer = new EventEmitter();
  httpServer.address = () => ({ port: 52963 });
  const plugin = localStack.vite({ coordinatorSocket: fixture.path, heartbeatIntervalMs: 30, quiet: true });
  t.after(() => plugin.closeBundle());
  plugin.configureServer({ httpServer, config: { server: { port: 5173 } } });
  httpServer.emit("listening");
  await until(() => registrations === 2);
  await until(() => fixture.requests.some(request => request.method === "service.heartbeat" && request.params.registrationID === "registration-2"));
  await plugin.closeBundle();
  const removals = fixture.requests.filter(request => request.method === "service.unregister");
  assert.equal(removals.length, 1);
  assert.equal(removals[0].params.registrationID, "registration-2");
  assert.ok(fixture.requests.filter(request => request.method === "service.register").every(request => request.params.port === 52963));
  const count = fixture.requests.length;
  await new Promise(resolve => setTimeout(resolve, 90));
  assert.equal(fixture.requests.length, count, "closed plugin kept sending requests");
});
