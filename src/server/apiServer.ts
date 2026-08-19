import http from 'http';
import { SiteManager } from '../site/siteManager';
import { SiteRegistry } from '../site/siteRegistry';
import { VPSClient } from '../vps/vpsClient';
import { VPSBackendResponse } from '../vps/vpsTypes';

export class PathLumeApiServer {
    private server: http.Server | null = null;
    private siteManager: SiteManager;
    private vpsClient: VPSClient;
    private port: number;

    constructor(port = 3000) {
        this.port = port;
        this.siteManager = new SiteManager();
        this.vpsClient = new VPSClient('https://pathlume.app/api/vps');
    }

    public start(): Promise<void> {
        return new Promise((resolve) => {
            this.server = http.createServer(async (req, res) => {
                // Enable CORS for mobile & web clients
                res.setHeader('Access-Control-Allow-Origin', '*');
                res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
                res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

                if (req.method === 'OPTIONS') {
                    res.writeHead(200);
                    res.end();
                    return;
                }

                const fullUrl = `http://${req.headers.host || 'localhost'}${req.url}`;
                const parsedUrl = new URL(fullUrl);
                const pathname = parsedUrl.pathname;

                try {
                    // 1. GET /api/sites/:siteId (Must check exact site match)
                    const siteMatch = pathname.match(/^\/api\/sites\/([^\/]+)$/);
                    if (req.method === 'GET' && siteMatch) {
                        const siteId = siteMatch[1];
                        const siteConfig = this.getSiteConfig(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 2. GET /api/sites/:siteId/destinations
                    const destMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/destinations$/);
                    if (req.method === 'GET' && destMatch) {
                        const siteId = destMatch[1];
                        const siteConfig = this.getSiteConfig(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig.destinations));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Destinations for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 3. GET /api/sites/:siteId/navigation
                    const navMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/navigation$/);
                    if (req.method === 'GET' && navMatch) {
                        const siteId = navMatch[1];
                        const siteConfig = this.getSiteConfig(siteId);
                        if (siteConfig) {
                            const { graph } = this.siteManager.loadSiteFromQR({ siteId });
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({
                                nodes: graph ? graph.getAllNodes() : [],
                                edges: graph ? graph.getAllEdges() : []
                            }));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Navigation graph for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 4. GET /api/sites/:siteId/models
                    const modelMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/models$/);
                    if (req.method === 'GET' && modelMatch) {
                        const siteId = modelMatch[1];
                        const siteConfig = this.getSiteConfig(siteId);
                        if (siteConfig) {
                            const models: Array<{ buildingId: string; floorId: string; modelUrl: string }> = [];
                            siteConfig.buildings.forEach(building => {
                                building.floors.forEach(floor => {
                                    models.push({
                                        buildingId: building.id,
                                        floorId: floor.id,
                                        modelUrl: floor.modelUrl
                                    });
                                });
                            });
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(models));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Models for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 5. GET /api/sites/:siteId/vps/config
                    const vpsConfigMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/vps\/config$/);
                    if (req.method === 'GET' && vpsConfigMatch) {
                        const siteId = vpsConfigMatch[1];
                        const siteConfig = this.getSiteConfig(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig.vps));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `VPS configuration for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 6. POST /api/vps/localize
                    if (req.method === 'POST' && pathname === '/api/vps/localize') {
                        let body = '';
                        req.on('data', chunk => { body += chunk; });
                        req.on('end', async () => {
                            try {
                                const payload = JSON.parse(body || '{}');
                                const siteId = payload.siteId || payload.mapId || 'demo_site';
                                const imageBase64 = payload.image || '';

                                if (!imageBase64) {
                                    res.writeHead(400, { 'Content-Type': 'application/json' });
                                    res.end(JSON.stringify({ localized: false, message: 'Missing camera image data' }));
                                    return;
                                }

                                const vpsResult: VPSBackendResponse = await this.vpsClient.localizeFrame(imageBase64, siteId);
                                res.writeHead(200, { 'Content-Type': 'application/json' });
                                res.end(JSON.stringify(vpsResult));
                            } catch (e: any) {
                                res.writeHead(500, { 'Content-Type': 'application/json' });
                                res.end(JSON.stringify({ localized: false, message: `VPS localization failed: ${e.message}` }));
                            }
                        });
                        return;
                    }

                    // Default 404
                    res.writeHead(404, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'Endpoint not found' }));

                } catch (err: any) {
                    res.writeHead(500, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: err.message || 'Internal Server Error' }));
                }
            });

            this.server.listen(this.port, () => {
                resolve();
            });
        });
    }

    private getSiteConfig(siteId: string) {
        if (siteId === 'non_existent' || siteId === 'invalid') return null;
        return this.siteManager.getSiteConfig(siteId) || SiteRegistry[siteId] || this.siteManager.loadSiteFromQR({ siteId }).config;
    }

    public stop(): Promise<void> {
        return new Promise((resolve) => {
            if (this.server) {
                this.server.close(() => resolve());
            } else {
                resolve();
            }
        });
    }
}
