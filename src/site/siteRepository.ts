import fs from 'fs';
import path from 'path';
import { SiteConfig } from './siteTypes';
import { DEFAULT_SITE_REGISTRY } from './siteRegistry';

export class SiteRepository {
    private storageDir: string;
    private modelsDir: string;

    constructor(baseStorageDir = './data/sites') {
        this.storageDir = path.resolve(baseStorageDir);
        this.modelsDir = path.resolve(baseStorageDir, 'models');
        this.initStorage();
    }

    private initStorage(): void {
        if (!fs.existsSync(this.storageDir)) {
            fs.mkdirSync(this.storageDir, { recursive: true });
        }
        if (!fs.existsSync(this.modelsDir)) {
            fs.mkdirSync(this.modelsDir, { recursive: true });
        }

        // Seed default sites if not already present
        for (const [siteId, siteConfig] of Object.entries(DEFAULT_SITE_REGISTRY)) {
            const file = path.join(this.storageDir, `${siteId}.json`);
            if (!fs.existsSync(file)) {
                this.saveSite(siteConfig);
            }
        }
    }

    public getSite(siteId: string): SiteConfig | null {
        const file = path.join(this.storageDir, `${siteId}.json`);
        if (!fs.existsSync(file)) {
            return DEFAULT_SITE_REGISTRY[siteId] || null;
        }
        try {
            const content = fs.readFileSync(file, 'utf-8');
            return JSON.parse(content) as SiteConfig;
        } catch (e) {
            return DEFAULT_SITE_REGISTRY[siteId] || null;
        }
    }

    public getAllSites(): SiteConfig[] {
        const sites: SiteConfig[] = [];
        const files = fs.readdirSync(this.storageDir);
        for (const file of files) {
            if (file.endsWith('.json')) {
                try {
                    const content = fs.readFileSync(path.join(this.storageDir, file), 'utf-8');
                    sites.push(JSON.parse(content));
                } catch (e) {
                    // Ignore invalid JSON files
                }
            }
        }

        // Merge defaults
        for (const [siteId, siteConfig] of Object.entries(DEFAULT_SITE_REGISTRY)) {
            if (!sites.some(s => s.siteId === siteId)) {
                sites.push(siteConfig);
            }
        }
        return sites;
    }

    public saveSite(site: SiteConfig): SiteConfig {
        site.version = (site.version || 0) + 1;
        const file = path.join(this.storageDir, `${site.siteId}.json`);
        fs.writeFileSync(file, JSON.stringify(site, null, 2), 'utf-8');
        return site;
    }

    public saveGlbModel(filename: string, fileBuffer: Buffer): { filename: string; sizeBytes: number; relativeUrl: string } {
        const safeName = filename.replace(/[^a-zA-Z0-9_\-\.]/g, '_');
        const targetPath = path.join(this.modelsDir, safeName);
        fs.writeFileSync(targetPath, fileBuffer);
        return {
            filename: safeName,
            sizeBytes: fileBuffer.length,
            relativeUrl: `/models/${safeName}`
        };
    }

    public getGlbModelPath(filename: string): string | null {
        const targetPath = path.join(this.modelsDir, filename);
        if (fs.existsSync(targetPath)) {
            return targetPath;
        }
        const samplePath = path.resolve('./examples/public/models', filename);
        if (fs.existsSync(samplePath)) {
            return samplePath;
        }
        return null;
    }

    public validateSiteForPublishing(site: SiteConfig): { valid: boolean; errors: string[] } {
        const errors: string[] = [];

        if (!site.siteId || site.siteId.trim().isEmpty()) {
            errors.push('Site ID is required');
        }
        if (!site.name || site.name.trim().isEmpty()) {
            errors.push('Site Name is required');
        }
        if (!site.buildings || site.buildings.length === 0) {
            errors.push('At least one Building is required');
        } else {
            site.buildings.forEach(b => {
                if (!b.floors || b.floors.length === 0) {
                    errors.push(`Building '${b.name || b.buildingId}' has no floors`);
                }
            });
        }

        if (!site.destinations || site.destinations.length === 0) {
            errors.push('At least one Destination is required');
        }

        if (!site.navigationGraph || !site.navigationGraph.nodes || site.navigationGraph.nodes.length === 0) {
            errors.push('Navigation graph must contain at least one node');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }
}

// Extension method helper
declare global {
    interface String {
        isEmpty(): boolean;
    }
}
String.prototype.isEmpty = function () {
    return this.length === 0;
};
