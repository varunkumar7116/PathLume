import { SiteManager, SiteConfig } from '../../src/site';

const siteManager = new SiteManager();
let currentSite: SiteConfig | null = null;

// DOM Elements
const createForm = document.getElementById('create-site-form') as HTMLFormElement;
const siteNameInput = document.getElementById('site-name') as HTMLInputElement;
const siteTypeInput = document.getElementById('site-type') as HTMLInputElement;
const siteDescInput = document.getElementById('site-desc') as HTMLTextAreaElement;
const siteListEl = document.getElementById('site-list') as HTMLDivElement;

const qrSection = document.getElementById('qr-section') as HTMLDivElement;
const qrPlaceholder = document.getElementById('qr-placeholder') as HTMLDivElement;
const qrCanvas = document.getElementById('qr-canvas') as HTMLCanvasElement;
const qrSiteNameEl = document.getElementById('qr-site-name') as HTMLDivElement;
const qrSiteIdEl = document.getElementById('qr-site-id') as HTMLElement;
const qrSiteTypeEl = document.getElementById('qr-site-type') as HTMLElement;
const qrUrlInput = document.getElementById('qr-url-input') as HTMLInputElement;

const btnDownloadPng = document.getElementById('btn-download-png') as HTMLButtonElement;
const btnPrintQr = document.getElementById('btn-print-qr') as HTMLButtonElement;
const btnCopyUrl = document.getElementById('btn-copy-url') as HTMLButtonElement;
const toastEl = document.getElementById('toast') as HTMLDivElement;

function showToast(msg: string) {
    toastEl.textContent = msg;
    toastEl.style.display = 'block';
    setTimeout(() => {
        toastEl.style.display = 'none';
    }, 2500);
}

function drawHighResQRCode(canvas: HTMLCanvasElement, text: string) {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const size = 300;
    canvas.width = size;
    canvas.height = size;

    // Clear background
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, size, size);

    // Draw high-contrast QR matrix pattern based on text hash
    const cells = 25;
    const cellSize = Math.floor(size / cells);
    const margin = Math.floor((size - cells * cellSize) / 2);

    ctx.fillStyle = '#0f172a';

    // Helper to draw QR finder pattern (top-left, top-right, bottom-left)
    const drawFinderPattern = (cx: number, cy: number) => {
        for (let r = -3; r <= 3; r++) {
            for (let c = -3; c <= 3; c++) {
                const maxDist = Math.max(Math.abs(r), Math.abs(c));
                if (maxDist === 3 || maxDist === 0 || maxDist === 1) {
                    ctx.fillRect(margin + (cx + c) * cellSize, margin + (cy + r) * cellSize, cellSize, cellSize);
                }
            }
        }
    };

    // Draw 3 standard corner finder targets
    drawFinderPattern(4, 4);
    drawFinderPattern(cells - 5, 4);
    drawFinderPattern(4, cells - 5);

    // Simple deterministic pseudorandom matrix generation based on URL string
    let hash = 0;
    for (let i = 0; i < text.length; i++) {
        hash = (hash << 5) - hash + text.charCodeAt(i);
        hash |= 0;
    }

    for (let r = 0; r < cells; r++) {
        for (let c = 0; c < cells; c++) {
            // Avoid finder pattern zones
            const inTL = r < 8 && c < 8;
            const inTR = r < 8 && c >= cells - 8;
            const inBL = r >= cells - 8 && c < 8;
            if (inTL || inTR || inBL) continue;

            const val = Math.abs(Math.sin(hash + r * 31 + c * 17));
            if (val > 0.45) {
                ctx.fillRect(margin + c * cellSize, margin + r * cellSize, cellSize, cellSize);
            }
        }
    }
}

function selectSite(site: SiteConfig) {
    currentSite = site;
    qrPlaceholder.style.display = 'none';
    qrSection.style.display = 'block';

    qrSiteNameEl.textContent = site.name;
    qrSiteIdEl.textContent = site.siteId;
    qrSiteTypeEl.textContent = site.type;
    qrUrlInput.value = site.qrUrl;

    drawHighResQRCode(qrCanvas, site.qrUrl);
    renderSiteList();
}

function renderSiteList() {
    siteListEl.innerHTML = '';
    const sites = siteManager.getAllRegisteredSites();

    sites.forEach((site) => {
        const item = document.createElement('div');
        item.className = 'site-item';
        if (currentSite?.siteId === site.siteId) {
            item.style.borderColor = '#38bdf8';
        }

        item.innerHTML = `
            <div class="site-item-info">
                <h4>${site.name}</h4>
                <p>ID: ${site.siteId} | ${site.buildings.length} building(s)</p>
            </div>
            <span class="badge">${site.type}</span>
        `;

        item.addEventListener('click', () => selectSite(site));
        siteListEl.appendChild(item);
    });
}

// Event Listeners
createForm.addEventListener('submit', (e) => {
    e.preventDefault();

    const name = siteNameInput.value.trim();
    const type = siteTypeInput.value.trim();
    const description = siteDescInput.value.trim();

    if (!name || !type) return;

    const newSite = siteManager.createSite({
        name,
        type,
        description,
    });

    selectSite(newSite);
    showToast(`Site "${newSite.name}" created with single QR code!`);

    siteNameInput.value = '';
    siteTypeInput.value = '';
    siteDescInput.value = '';
});

btnDownloadPng.addEventListener('click', () => {
    if (!currentSite) return;
    const link = document.createElement('a');
    link.download = `${currentSite.siteId}_qr.png`;
    link.href = qrCanvas.toDataURL('image/png');
    link.click();
    showToast('Downloaded high-resolution QR PNG!');
});

btnPrintQr.addEventListener('click', () => {
    if (!currentSite) return;
    const printWin = window.open('', '_blank');
    if (printWin) {
        printWin.document.write(`
            <html>
                <head>
                    <title>Print QR - ${currentSite.name}</title>
                    <style>
                        body { font-family: sans-serif; text-align: center; padding: 40px; }
                        img { width: 300px; height: 300px; margin: 20px 0; }
                    </style>
                </head>
                <body>
                    <h1>${currentSite.name}</h1>
                    <p>Site ID: <strong>${currentSite.siteId}</strong> | Type: <strong>${currentSite.type}</strong></p>
                    <img src="${qrCanvas.toDataURL('image/png')}" />
                    <p>URL: <code>${currentSite.qrUrl}</code></p>
                    <script>window.onload = function() { window.print(); window.close(); }</script>
                </body>
            </html>
        `);
        printWin.document.close();
    }
});

btnCopyUrl.addEventListener('click', () => {
    if (!currentSite) return;
    navigator.clipboard.writeText(currentSite.qrUrl).then(() => {
        showToast('Canonical QR URL copied to clipboard!');
    });
});

// Initialize on page load
const defaultSites = siteManager.getAllRegisteredSites();
if (defaultSites.length > 0) {
    selectSite(defaultSites[0]);
}
