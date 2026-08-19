import { VPSBackendResponse } from './vpsTypes';

export class MockVPSServer {
    private isEnabled = true;
    private simulatedStep = 0;

    // Simulated trajectory points along building corridor
    private simulatedPath = [
        { position: { x: 0.0, y: 0.0, z: 6.5 }, heading: 180, accuracy: 0.4 },
        { position: { x: 0.0, y: 0.0, z: 5.0 }, heading: 180, accuracy: 0.35 },
        { position: { x: 0.0, y: 0.0, z: 3.5 }, heading: 180, accuracy: 0.3 },
        { position: { x: -0.8, y: 0.0, z: 3.5 }, heading: 270, accuracy: 0.4 },
        { position: { x: -1.8, y: 0.0, z: 3.5 }, heading: 270, accuracy: 0.5 },
        { position: { x: -1.8, y: 0.0, z: 2.0 }, heading: 180, accuracy: 0.45 },
        { position: { x: -1.8, y: 0.0, z: 0.0 }, heading: 180, accuracy: 0.3 },
        { position: { x: -1.8, y: 0.0, z: -2.0 }, heading: 180, accuracy: 0.4 },
    ];

    public setEnabled(enabled: boolean): void {
        this.isEnabled = enabled;
    }

    /**
     * Intercepts standard fetch requests to the VPS backend endpoint
     * if no live server is running.
     */
    public enableFetchInterceptor(serverUrl: string): void {
        const originalFetch = window.fetch;
        window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
            const urlStr = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;

            if (this.isEnabled && urlStr.includes(serverUrl)) {
                let reqBody: any = {};
                try {
                    if (init && init.body) {
                        reqBody = JSON.parse(init.body as string);
                    }
                } catch {
                    // Ignore body parse errors
                }

                const responseData = this.handleLocalizeRequest(reqBody);

                return new Response(JSON.stringify(responseData), {
                    status: 200,
                    headers: { 'Content-Type': 'application/json' },
                });
            }

            return originalFetch(input, init);
        };
    }

    public handleLocalizeRequest(requestPayload: any): VPSBackendResponse {
        if (!requestPayload || !requestPayload.image) {
            return {
                localized: false,
                message: 'No image frame provided',
            };
        }

        // Return next pose in trajectory simulation loop
        const step = this.simulatedPath[this.simulatedStep % this.simulatedPath.length];
        this.simulatedStep++;

        return {
            localized: true,
            mapId: requestPayload.mapId || 'building_01',
            floor: 1,
            position: { ...step.position },
            rotation: { x: 0, y: Math.sin((step.heading * Math.PI) / 360), z: 0, w: Math.cos((step.heading * Math.PI) / 360) },
            heading: step.heading,
            accuracy: step.accuracy,
        };
    }
}
