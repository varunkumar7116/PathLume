import fs from 'fs';
import path from 'path';
import { generateSoloNavMesh } from '../dist/blocks.js';
import { findNearestPoly, findPath, createFindNearestPolyResult, DEFAULT_QUERY_FILTER } from '../dist/index.js';

// Read sample1.glb file buffer
const glbPath = path.resolve('./examples/public/models/sample1.glb');
const glbBuffer = fs.readFileSync(glbPath);

function parseGLB(buffer) {
    const dataView = new DataView(buffer.buffer, buffer.byteOffset, buffer.byteLength);
    const magic = dataView.getUint32(0, true);
    if (magic !== 0x46546c67) throw new Error('Invalid GLB magic');
    const length = dataView.getUint32(8, true);

    let pos = 12;
    let jsonChunk = null;
    let binChunk = null;

    while (pos < length) {
        const chunkLength = dataView.getUint32(pos, true);
        const chunkType = dataView.getUint32(pos + 4, true);
        const chunkData = buffer.subarray(pos + 8, pos + 8 + chunkLength);
        if (chunkType === 0x4E4F534A) {
            jsonChunk = JSON.parse(new TextDecoder().decode(chunkData));
        } else {
            if (!binChunk) binChunk = chunkData;
        }
        pos += 8 + chunkLength;
    }
    return { json: jsonChunk, bin: binChunk };
}

const { json, bin } = parseGLB(glbBuffer);

const mesh = json.meshes[0];
const prim = mesh.primitives[0];

function getArray(accessorIndex) {
    const acc = json.accessors[accessorIndex];
    const bv = json.bufferViews[acc.bufferView];
    const offset = (bv.byteOffset || 0) + (acc.byteOffset || 0);
    const count = acc.count;

    const byteLen = count * (acc.type === 'VEC3' ? 12 : acc.type === 'SCALAR' ? 2 : 4);
    const sub = bin.subarray(offset, offset + byteLen);
    const sliced = new Uint8Array(sub).buffer;

    if (acc.componentType === 5126) return new Float32Array(sliced);
    if (acc.componentType === 5125) return new Uint32Array(sliced);
    if (acc.componentType === 5123) return new Uint16Array(sliced);
    throw new Error('Unsupported component type');
}

const positions = getArray(prim.attributes.POSITION);
const indicesRaw = getArray(prim.indices);
const indices = new Uint32Array(indicesRaw.length);
for (let i = 0; i < indicesRaw.length; i++) indices[i] = indicesRaw[i];

console.log('==================================================');
console.log('STAGE A — MODEL GEOMETRY & NORMAL ANALYSIS (sample1.glb)');
console.log('==================================================');
console.log('Input Vertices:', (positions.length / 3).toLocaleString());
console.log('Input Triangles:', (indices.length / 3).toLocaleString());

let minX = Infinity, minY = Infinity, minZ = Infinity;
let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;

for (let i = 0; i < positions.length; i += 3) {
    const x = positions[i], y = positions[i + 1], z = positions[i + 2];
    if (x < minX) minX = x; if (x > maxX) maxX = x;
    if (y < minY) minY = y; if (y > maxY) maxY = y;
    if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
}

console.log(`Bounding Box Min: (${minX.toFixed(2)}, ${minY.toFixed(2)}, ${minZ.toFixed(2)})`);
console.log(`Bounding Box Max: (${maxX.toFixed(2)}, ${maxY.toFixed(2)}, ${maxZ.toFixed(2)})`);
console.log(`Dimensions (X x Y x Z): ${(maxX - minX).toFixed(2)} x ${(maxY - minY).toFixed(2)} x ${(maxZ - minZ).toFixed(2)}`);

// Triangle Normal Orientation Statistics
let upTriangles = 0;
let downTriangles = 0;
let vertTriangles = 0;
const cosSlope45 = Math.cos((45 * Math.PI) / 180);

for (let i = 0; i < indices.length; i += 3) {
    const i0 = indices[i] * 3, i1 = indices[i + 1] * 3, i2 = indices[i + 2] * 3;
    const ax = positions[i0], ay = positions[i0 + 1], az = positions[i0 + 2];
    const bx = positions[i1], by = positions[i1 + 1], bz = positions[i1 + 2];
    const cx = positions[i2], cy = positions[i2 + 1], cz = positions[i2 + 2];

    const e1x = bx - ax, e1y = by - ay, e1z = bz - az;
    const e2x = cx - ax, e2y = cy - ay, e2z = cz - az;
    const nx = e1y * e2z - e1z * e2y;
    const ny = e1z * e2x - e1x * e2z;
    const nz = e1x * e2y - e1y * e2x;
    const len = Math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len > 0) {
        const normY = ny / len;
        if (normY >= cosSlope45) upTriangles++;
        else if (normY <= -cosSlope45) downTriangles++;
        else vertTriangles++;
    }
}

console.log('Upward-facing triangles (slope <= 45°):', upTriangles.toLocaleString());
console.log('Downward-facing triangles (slope >= 135°):', downTriangles.toLocaleString());
console.log('Near-vertical / Wall triangles:', vertTriangles.toLocaleString());

// Build NavMesh using Photogrammetry Filter & Preset 3 Settings
const floorMaxY = minY + Math.max(1.8, (maxY - minY) * 0.45);
const filtered = [];
for (let i = 0; i < indices.length; i += 3) {
    const i0 = indices[i] * 3, i1 = indices[i + 1] * 3, i2 = indices[i + 2] * 3;
    const ax = positions[i0], ay = positions[i0 + 1], az = positions[i0 + 2];
    const bx = positions[i1], by = positions[i1 + 1], bz = positions[i1 + 2];
    const cx = positions[i2], cy = positions[i2 + 1], cz = positions[i2 + 2];

    const e1x = bx - ax, e1y = by - ay, e1z = bz - az;
    const e2x = cx - ax, e2y = cy - ay, e2z = cz - az;
    const nx = e1y * e2z - e1z * e2y;
    const ny = e1z * e2x - e1x * e2z;
    const nz = e1x * e2y - e1y * e2x;
    const len = Math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len > 0) {
        const normY = ny / len;
        const maxTriY = Math.max(ay, by, cy);
        if (normY >= (cosSlope45 - 0.25) && maxTriY <= floorMaxY) {
            filtered.push(indices[i], indices[i + 1], indices[i + 2]);
        }
    }
}

const filteredIndices = new Uint32Array(filtered);

const options = {
    cellSize: 0.10,
    cellHeight: 0.08,
    walkableRadiusWorld: 0.08,
    walkableRadiusVoxels: Math.ceil(0.08 / 0.10),
    walkableClimbWorld: 0.4,
    walkableClimbVoxels: Math.ceil(0.4 / 0.08),
    walkableHeightWorld: 1.0,
    walkableHeightVoxels: Math.ceil(1.0 / 0.08),
    walkableSlopeAngleDegrees: 60,
    borderSize: 0,
    minRegionArea: 1,
    mergeRegionArea: 4,
    maxSimplificationError: 1.3,
    maxEdgeLength: 12,
    maxVerticesPerPoly: 6,
    detailSampleDistance: 0.9,
    detailSampleMaxError: 0.15,
};

const startTime = performance.now();
const result = generateSoloNavMesh({ positions, indices: filteredIndices }, options);
const duration = performance.now() - startTime;
const navMesh = result.navMesh;

let polyCount = 0;
for (const tile of Object.values(navMesh.tiles)) {
    if (tile && tile.polys) polyCount += tile.polys.length;
}

console.log('\n========================================');
console.log('NAVMESH GENERATION RESULTS');
console.log('========================================');
console.log('Walkable Candidate Triangles:', (filteredIndices.length / 3).toLocaleString());
console.log('Heightfield Grid Size:', result.intermediates.heightfield.width, 'x', result.intermediates.heightfield.height);
console.log('Compact Heightfield Spans:', result.intermediates.compactHeightfield.spanCount);
console.log('Contours Count:', result.intermediates.contourSet.contours.length);
console.log('PolyMesh Polygons:', result.intermediates.polyMesh.nPolys);
console.log('--> NAVMESH POLYGON COUNT:', polyCount);
console.log('--> GENERATION TIME:', `${duration.toFixed(1)} ms`);

console.log('\n========================================');
console.log('STAGE B — PATHFINDING TESTS');
console.log('========================================');

const halfExtents = [5, 5, 5];

function runPathTest(testName, startRaw, destRaw) {
    console.log(`\n--- ${testName} ---`);
    console.log(`Raw Start: [${startRaw.map(v=>v.toFixed(2)).join(', ')}]`);
    console.log(`Raw Dest:  [${destRaw.map(v=>v.toFixed(2)).join(', ')}]`);

    const startSnap = createFindNearestPolyResult();
    findNearestPoly(startSnap, navMesh, startRaw, halfExtents, DEFAULT_QUERY_FILTER);

    const destSnap = createFindNearestPolyResult();
    findNearestPoly(destSnap, navMesh, destRaw, halfExtents, DEFAULT_QUERY_FILTER);

    console.log(`Start Snap Success: ${startSnap.success}, Poly ID: ${startSnap.nodeRef}, Snapped: [${startSnap.position.map(v=>v.toFixed(2)).join(', ')}]`);
    console.log(`Dest Snap Success:  ${destSnap.success}, Poly ID: ${destSnap.nodeRef}, Snapped: [${destSnap.position.map(v=>v.toFixed(2)).join(', ')}]`);

    if (startSnap.success && destSnap.success) {
        const pathRes = findPath(navMesh, startSnap.position, destSnap.position, halfExtents, DEFAULT_QUERY_FILTER);
        const path = pathRes.path;

        if (path && path.length > 0) {
            let totalDist = 0;
            for (let i = 1; i < path.length; i++) {
                const p1 = path[i - 1].position;
                const p2 = path[i].position;
                const dx = p2[0] - p1[0], dy = p2[1] - p1[1], dz = p2[2] - p1[2];
                totalDist += Math.sqrt(dx * dx + dy * dy + dz * dz);
            }
            console.log(`Path Found: YES (Success)`);
            console.log(`Waypoints Count: ${path.length}`);
            console.log(`Total Distance: ${totalDist.toFixed(2)} meters`);
            console.log('Waypoints:');
            path.forEach((pt, idx) => {
                console.log(`  [${idx}] (X: ${pt.position[0].toFixed(2)}, Y: ${pt.position[1].toFixed(2)}, Z: ${pt.position[2].toFixed(2)})`);
            });
        } else {
            console.log('Path Found: NO');
        }
    } else {
        console.log('Snap failed: Point not on navigable surface');
    }
}

// Test 1: Along main hallway section
runPathTest('PATH TEST 1', [0.2, -1.8, -4.0], [-0.3, -1.8, 3.5]);

// Test 2: Across room/doorway section
runPathTest('PATH TEST 2', [-0.5, -1.8, -2.0], [0.8, -1.8, 1.5]);
