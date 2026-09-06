import { createUnplugin } from "unplugin";
import net from "node:net";
export function isLoopbackURL(value) {
    try {
        const url = new URL(value);
        return url.protocol === "http:" && ["localhost", "127.0.0.1", "[::1]", "::1"].includes(url.hostname.toLowerCase());
    }
    catch {
        return false;
    }
}
export function buildRegistrationParams(options, port, pid = process.pid) {
    const url = options.url ?? `http://127.0.0.1:${port}/`;
    return {
        pid,
        port,
        url,
        displayName: options.name,
        projectRoot: options.projectRoot,
        source: "unplugin",
    };
}
function defaultSocketPath() {
    return process.env.LOCALSTACK_SOCKET ?? `${process.env.HOME ?? process.cwd()}/Library/Application Support/LocalStack/coordinator.sock`;
}
async function callCoordinator(socketPath, method, params) {
    return await new Promise((resolve, reject) => {
        const socket = net.createConnection({ path: socketPath });
        const chunks = [];
        const timeout = setTimeout(() => socket.destroy(new Error("Coordinator 请求超时")), 5000);
        const finish = () => clearTimeout(timeout);
        socket.on("connect", () => {
            socket.end(`${JSON.stringify({ id: `unplugin-${Date.now()}`, method, params })}\n`);
        });
        socket.on("data", (chunk) => chunks.push(Buffer.from(chunk)));
        socket.on("error", (error) => {
            finish();
            reject(error);
        });
        socket.on("end", () => {
            finish();
            try {
                const response = JSON.parse(Buffer.concat(chunks).toString("utf8"));
                if (response.error)
                    reject(new Error(`${response.error.code}: ${response.error.message}`));
                else
                    resolve(response.result);
            }
            catch (error) {
                reject(error);
            }
        });
    });
}
/** Thin SDK client for non-Vite development servers. */
export async function register(options) {
    const params = {
        pid: options.pid ?? process.pid,
        port: options.port,
        url: options.url ?? `http://127.0.0.1:${options.port}/`,
        displayName: options.displayName,
        projectRoot: options.projectRoot,
        source: "sdk",
    };
    return await callCoordinator(options.coordinatorSocket ?? defaultSocketPath(), "service.register", params);
}
export async function heartbeat(lease, coordinatorSocket) {
    return await callCoordinator(coordinatorSocket ?? defaultSocketPath(), "service.heartbeat", { registrationID: lease.registrationID, leaseToken: lease.leaseToken });
}
export async function unregister(lease, coordinatorSocket) {
    await callCoordinator(coordinatorSocket ?? defaultSocketPath(), "service.unregister", { registrationID: lease.registrationID, leaseToken: lease.leaseToken });
}
function portFromServer(server, fallback) {
    const address = server?.address();
    if (address && typeof address === "object" && "port" in address)
        return address.port;
    return fallback;
}
function notify(options, message) {
    if (!options.quiet)
        console.warn(`[LocalStack] ${message}`);
}
export const localStack = createUnplugin((options = {}) => {
    let lease;
    let heartbeat;
    let retryTimer;
    let registering = false;
    let closed = false;
    let warnedUnavailable = false;
    let activeServer;
    let activePort;
    async function register(server, configuredPort) {
        if (closed || lease || registering)
            return;
        registering = true;
        const port = portFromServer(server, configuredPort ?? 5173);
        activeServer = server;
        activePort = port;
        try {
            const registration = await callCoordinator(options.coordinatorSocket ?? defaultSocketPath(), "service.register", buildRegistrationParams(options, port));
            if (closed) {
                await callCoordinator(options.coordinatorSocket ?? defaultSocketPath(), "service.unregister", {
                    registrationID: registration.registrationID,
                    leaseToken: registration.leaseToken,
                });
                return;
            }
            lease = registration;
            warnedUnavailable = false;
            const interval = options.heartbeatIntervalMs ?? 15_000;
            if (heartbeat)
                clearInterval(heartbeat);
            heartbeat = setInterval(() => {
                const current = lease;
                if (!current || closed)
                    return;
                void callCoordinator(options.coordinatorSocket ?? defaultSocketPath(), "service.heartbeat", {
                    registrationID: current.registrationID,
                    leaseToken: current.leaseToken,
                }).catch((error) => {
                    // A coordinator restart invalidates in-memory leases. Re-register in place.
                    if (lease?.registrationID !== current.registrationID || closed)
                        return;
                    lease = undefined;
                    if (heartbeat) {
                        clearInterval(heartbeat);
                        heartbeat = undefined;
                    }
                    if (!warnedUnavailable) {
                        notify(options, `heartbeat 失败：${error.message}，正在重新注册`);
                        warnedUnavailable = true;
                    }
                    void register(activeServer, activePort);
                });
            }, interval);
        }
        catch (error) {
            if (!warnedUnavailable) {
                notify(options, `未注册开发服务：${error.message}（不会阻断 dev server）`);
                warnedUnavailable = true;
            }
            if (!closed) {
                retryTimer = setTimeout(() => {
                    retryTimer = undefined;
                    void register(activeServer, activePort);
                }, Math.min(Math.max(intervalForRetry(options), 1000), 30_000));
            }
        }
        finally {
            registering = false;
        }
    }
    function intervalForRetry(currentOptions) {
        return currentOptions.heartbeatIntervalMs ?? 5_000;
    }
    async function unregister() {
        closed = true;
        if (retryTimer)
            clearTimeout(retryTimer);
        retryTimer = undefined;
        if (heartbeat)
            clearInterval(heartbeat);
        heartbeat = undefined;
        if (!lease)
            return;
        const current = lease;
        lease = undefined;
        try {
            await callCoordinator(options.coordinatorSocket ?? defaultSocketPath(), "service.unregister", {
                registrationID: current.registrationID,
                leaseToken: current.leaseToken,
            });
        }
        catch (error) {
            notify(options, `注销开发服务失败：${error.message}`);
        }
    }
    return {
        name: "localstack",
        vite: {
            configureServer(devServer) {
                const httpServer = devServer.httpServer;
                if (httpServer)
                    httpServer.once("listening", () => void register(httpServer, devServer.config.server.port));
                else
                    setTimeout(() => void register(httpServer, devServer.config.server.port), 0);
                httpServer?.once("close", () => void unregister());
            },
        },
        buildStart() {
            // Rollup-compatible adapters can call register through the same lifecycle when they expose a server.
        },
        closeBundle() {
            return unregister();
        },
    };
});
export default localStack;
