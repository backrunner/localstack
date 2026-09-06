import test from "node:test";
import assert from "node:assert/strict";
import { buildRegistrationParams, isLoopbackURL, register, heartbeat, unregister } from "../dist/index.js";

test("only accepts HTTP loopback URLs", () => {
  assert.equal(isLoopbackURL("http://127.0.0.1:5173/"), true);
  assert.equal(isLoopbackURL("http://localhost:3000"), true);
  assert.equal(isLoopbackURL("https://example.com"), false);
  assert.equal(isLoopbackURL("http://192.168.1.4:3000"), false);
});

test("registration payload is explicit and stable", () => {
  assert.deepEqual(buildRegistrationParams({ name: "Console", projectRoot: "/tmp/project" }, 4173, 42), {
    pid: 42,
    port: 4173,
    url: "http://127.0.0.1:4173/",
    displayName: "Console",
    projectRoot: "/tmp/project",
    source: "unplugin",
  });
});

test("SDK exports the lifecycle API", () => {
  assert.equal(typeof register, "function");
  assert.equal(typeof heartbeat, "function");
  assert.equal(typeof unregister, "function");
});
