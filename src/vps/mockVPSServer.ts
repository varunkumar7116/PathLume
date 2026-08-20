import { VPSBackendResponse } from './vpsTypes';

export class MockVPSServer {
    private isEnabled = false;

    public setEnabled(enabled: boolean): void {
        this.isEnabled = enabled;
    }

    /**
     * Intercepts standard fetch requests to the VPS backend endpoint.
     */
    public enableFetchInterceptor(serverUrl: string): void {
        const originalFetch = window.fetch;
        window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
            const urlStr = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;

            if (this.isEnabled && urlStr.includes(serverUrl)) {
                const responseData: VPSBackendResponse = {
                    localized: false,
                    message: 'VPS BLOCKED — Real VPS provider configuration required',
                };

                return new Response(JSON.stringify(responseData), {
                    status: 530,
                    headers: { 'Content-Type': 'application/json' },
                });
            }

            return originalFetch(input, init);
        };
    }

    public handleLocalizeRequest(_requestPayload: any): VPSBackendResponse {
        return {
            localized: false,
            message: 'VPS BLOCKED — Real VPS provider configuration required',
        };
    }
}
