import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PathLumeApiServer } from '../src/server/apiServer';

describe('PathLume REST API Server', () => {
    const port = 3099;
    const baseUrl = `http://localhost:${port}`;
    let server: PathLumeApiServer;

    beforeAll(async () => {
        server = new PathLumeApiServer(port);
        await server.start();
    });

    afterAll(async () => {
        await server.stop();
    });

    it('GET /api/sites/demo_site returns site configuration', async () => {
        const response = await fetch(`${baseUrl}/api/sites/demo_site`);
        expect(response.status).toBe(200);
        const data = await response.json();
        expect(data.siteId).toBe('demo_site');
        expect(data.buildings.length).toBeGreaterThan(0);
    });

    it('GET /api/sites/demo_site/destinations returns site destinations', async () => {
        const response = await fetch(`${baseUrl}/api/sites/demo_site/destinations`);
        expect(response.status).toBe(200);
        const destinations = await response.json();
        expect(Array.isArray(destinations)).toBe(true);
        expect(destinations.length).toBeGreaterThan(0);
    });

    it('GET /api/sites/demo_site/navigation returns navigation graph nodes and edges', async () => {
        const response = await fetch(`${baseUrl}/api/sites/demo_site/navigation`);
        expect(response.status).toBe(200);
        const navData = await response.json();
        expect(navData.nodes).toBeDefined();
        expect(navData.edges).toBeDefined();
    });

    it('GET /api/sites/demo_site/models returns 3D GLB model references', async () => {
        const response = await fetch(`${baseUrl}/api/sites/demo_site/models`);
        expect(response.status).toBe(200);
        const models = await response.json();
        expect(models.length).toBeGreaterThan(0);
        expect(models[0].modelUrl).toBeDefined();
    });

    it('GET /api/sites/non_existent returns 404 error', async () => {
        const response = await fetch(`${baseUrl}/api/sites/non_existent`);
        expect(response.status).toBe(404);
    });
});
