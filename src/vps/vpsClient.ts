import { VPSBackendResponse } from './vpsTypes';

export class VPSClient {
    private serverUrl: string;
    private lastLatencyMs = 0;

    constructor(serverUrl: string) {
        this.serverUrl = serverUrl;
    }

    public setServerUrl(url: string): void {
        this.serverUrl = url;
    }

    public getServerUrl(): string {
        return this.serverUrl;
    }

    public getLastLatencyMs(): number {
        return this.lastLatencyMs;
    }

    /**
     * Sends camera image frame to VPS Backend for visual localization.
     */
    public async localizeFrame(
        imageFrameBase64: string,
        mapId = 'building_01'
    ): Promise<VPSBackendResponse> {
        const startTime = performance.now();
        try {
            const response = await fetch(this.serverUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    mapId,
                    image: imageFrameBase64,
                    timestamp: Date.now(),
                }),
            });

            this.lastLatencyMs = Math.round(performance.now() - startTime);

            if (!response.ok) {
                return {
                    localized: false,
                    message: `VPS Server Error (${response.status}): ${response.statusText}`,
                };
            }

            const data: VPSBackendResponse = await response.json();
            return data;
        } catch (err: any) {
            this.lastLatencyMs = Math.round(performance.now() - startTime);
            return {
                localized: false,
                message: `Network/VPS Request Failed: ${err.message || err}`,
            };
        }
    }
}
