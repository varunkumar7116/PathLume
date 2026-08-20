import http from 'http';
import { SiteRepository } from '../site/siteRepository';
import { VPSClient } from '../vps/vpsClient';
import { VPSBackendResponse } from '../vps/vpsTypes';
import { SiteConfig } from '../site/siteTypes';

export class PathLumeApiServer {
    private server: http.Server | null = null;
    private siteRepository: SiteRepository;
    private vpsClient: VPSClient;
    private port: number;

    constructor(port = 3000) {
        this.port = port;
        this.siteRepository = new SiteRepository();
        this.vpsClient = new VPSClient('https://pathlume.app/api/vps');
    }

    public start(): Promise<void> {
        return new Promise((resolve) => {
            this.server = http.createServer(async (req: http.IncomingMessage, res: http.ServerResponse) => {
                // CORS Headers
                res.setHeader('Access-Control-Allow-Origin', '*');
                res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
                res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');

                if (req.method === 'OPTIONS') {
                    res.writeHead(200);
                    res.end();
                    return;
                }

                const fullUrl = `http://${req.headers.host || 'localhost'}${req.url}`;
                const parsedUrl = new URL(fullUrl);
                const pathname = parsedUrl.pathname;

                try {
                    // 1. GET /api/sites
                    if (req.method === 'GET' && pathname === '/api/sites') {
                        const sites = this.siteRepository.getAllSites();
                        res.writeHead(200, { 'Content-Type': 'application/json' });
                        res.end(JSON.stringify(sites));
                        return;
                    }

                    // 2. GET /api/sites/:siteId
                    const siteMatch = pathname.match(/^\/api\/sites\/([^\/]+)$/);
                    if (req.method === 'GET' && siteMatch) {
                        const siteId = siteMatch[1];
                        const siteConfig = this.siteRepository.getSite(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 3. GET /api/sites/:siteId/destinations
                    const destMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/destinations$/);
                    if (req.method === 'GET' && destMatch) {
                        const siteId = destMatch[1];
                        const siteConfig = this.siteRepository.getSite(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig.destinations || []));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Destinations for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 4. GET /api/sites/:siteId/navigation or /api/sites/:siteId/graph
                    const navMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/(navigation|graph)$/);
                    if (req.method === 'GET' && navMatch) {
                        const siteId = navMatch[1];
                        const siteConfig = this.siteRepository.getSite(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig.navigationGraph || { nodes: [], edges: [] }));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Navigation graph for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 5. GET /api/sites/:siteId/models
                    const modelMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/models$/);
                    if (req.method === 'GET' && modelMatch) {
                        const siteId = modelMatch[1];
                        const siteConfig = this.siteRepository.getSite(siteId);
                        if (siteConfig) {
                            const models: Array<{ buildingId: string; floorId: string; modelUrl: string }> = [];
                            siteConfig.buildings.forEach(b => {
                                b.floors.forEach(f => {
                                    models.push({
                                        buildingId: b.buildingId,
                                        floorId: f.floorId,
                                        modelUrl: f.modelUrl
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

                    // 6. GET /api/sites/:siteId/vps/config
                    const vpsConfigMatch = pathname.match(/^\/api\/sites\/([^\/]+)\/vps\/config$/);
                    if (req.method === 'GET' && vpsConfigMatch) {
                        const siteId = vpsConfigMatch[1];
                        const siteConfig = this.siteRepository.getSite(siteId);
                        if (siteConfig) {
                            res.writeHead(200, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify(siteConfig.vps));
                        } else {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `VPS configuration for site '${siteId}' not found.` }));
                        }
                        return;
                    }

                    // 7. ADMIN: POST /api/admin/sites (Create or update site)
                    if ((req.method === 'POST' || req.method === 'PUT') && pathname === '/api/admin/sites') {
                        let body = '';
                        req.on('data', (chunk: Buffer | string) => { body += chunk; });
                        req.on('end', () => {
                            try {
                                const siteData: SiteConfig = JSON.parse(body || '{}');
                                if (!siteData.siteId) {
                                    res.writeHead(400, { 'Content-Type': 'application/json' });
                                    res.end(JSON.stringify({ error: 'siteId is required' }));
                                    return;
                                }
                                const saved = this.siteRepository.saveSite(siteData);
                                res.writeHead(200, { 'Content-Type': 'application/json' });
                                res.end(JSON.stringify(saved));
                            } catch (e: any) {
                                res.writeHead(400, { 'Content-Type': 'application/json' });
                                res.end(JSON.stringify({ error: `Invalid JSON payload: ${e.message}` }));
                            }
                        });
                        return;
                    }

                    // 8. ADMIN: POST /api/admin/sites/:siteId/publish
                    const publishMatch = pathname.match(/^\/api\/admin\/sites\/([^\/]+)\/publish$/);
                    if (req.method === 'POST' && publishMatch) {
                        const siteId = publishMatch[1];
                        const siteConfig = this.siteRepository.getSite(siteId);
                        if (!siteConfig) {
                            res.writeHead(404, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: `Site '${siteId}' not found.` }));
                            return;
                        }

                        const validation = this.siteRepository.validateSiteForPublishing(siteConfig);
                        if (!validation.valid) {
                            res.writeHead(422, { 'Content-Type': 'application/json' });
                            res.end(JSON.stringify({ error: 'Site validation failed before publishing', details: validation.errors }));
                            return;
                        }

                        siteConfig.status = 'active';
                        siteConfig.publishedAt = Date.now();
                        const published = this.siteRepository.saveSite(siteConfig);

                        res.writeHead(200, { 'Content-Type': 'application/json' });
                        res.end(JSON.stringify({
                            message: `Site '${siteId}' successfully published!`,
                            site: published
                        }));
                        return;
                    }

                    // 9. POST /api/vps/localize
                    if (req.method === 'POST' && pathname === '/api/vps/localize') {
                        let body = '';
                        req.on('data', (chunk: Buffer | string) => { body += chunk; });
                        req.on('end', async () => {
                            try {
                                const payload = JSON.parse(body || '{}');
                                const siteId = payload.siteId || payload.mapId || 'demo_site';
                                const imageBase64 = payload.image || payload.queryFeatures || '';

                                if (!imageBase64 || (Array.isArray(imageBase64) && imageBase64.length === 0)) {
                                    res.writeHead(400, { 'Content-Type': 'application/json' });
                                    res.end(JSON.stringify({ localized: false, message: 'Missing camera image or queryFeatures data' }));
                                    return;
                                }

                                try {
                                    const vpsResult: VPSBackendResponse = await this.vpsClient.localizeFrame(imageBase64, siteId);
                                    res.writeHead(200, { 'Content-Type': 'application/json' });
                                    res.end(JSON.stringify(vpsResult));
                                } catch {
                                    // If no external live VPS backend is configured, return explicit UNAVAILABLE status
                                    res.writeHead(503, { 'Content-Type': 'application/json' });
                                    res.end(JSON.stringify({
                                        localized: false,
                                        status: 'UNAVAILABLE',
                                        message: 'VPS BLOCKED — Real VPS provider configuration required'
                                    }));
                                }
                            } catch (e: any) {
                                res.writeHead(500, { 'Content-Type': 'application/json' });
                                res.end(JSON.stringify({ localized: false, message: `VPS localization error: ${e.message}` }));
                            }
                        });
                        return;
                    }

                    // Default 404
                    res.writeHead(404, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: `Endpoint '${pathname}' not found` }));

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

// Auto-start if executed directly via CLI
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('apiServer.ts') || process.argv[1]?.endsWith('apiServer.js')) {
    const port = Number(process.env.PORT) || 8080;
    const server = new PathLumeApiServer(port);
    server.start().then(() => {
        console.log(`🚀 PathLume REST API Server running at http://localhost:${port}`);
        console.log(`📡 Sites Endpoint: http://localhost:${port}/api/sites`);
        console.log(`📡 Sample Site:    http://localhost:${port}/api/sites/demo_site`);
    });
}

