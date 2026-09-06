export interface LocalStackPluginOptions {
    name?: string;
    projectRoot?: string;
    url?: string;
    coordinatorSocket?: string;
    heartbeatIntervalMs?: number;
    quiet?: boolean;
}
export interface LeaseResponse {
    service: {
        id: string;
    };
    registrationID: string;
    leaseToken: string;
    leaseExpiresAt: string;
}
export interface LocalStackSDKOptions {
    pid?: number;
    port: number;
    url?: string;
    displayName?: string;
    projectRoot?: string;
    coordinatorSocket?: string;
}
export declare function isLoopbackURL(value: string): boolean;
export declare function buildRegistrationParams(options: LocalStackPluginOptions, port: number, pid?: number): {
    pid: number;
    port: number;
    url: string;
    displayName: string | undefined;
    projectRoot: string | undefined;
    source: string;
};
/** Thin SDK client for non-Vite development servers. */
export declare function register(options: LocalStackSDKOptions): Promise<LeaseResponse>;
export declare function heartbeat(lease: Pick<LeaseResponse, "registrationID" | "leaseToken">, coordinatorSocket?: string): Promise<{
    expiresAt: string;
}>;
export declare function unregister(lease: Pick<LeaseResponse, "registrationID" | "leaseToken">, coordinatorSocket?: string): Promise<void>;
export declare const localStack: import("unplugin").UnpluginInstance<LocalStackPluginOptions | undefined, boolean>;
export default localStack;
