# navcat Project File Structure

```text
navcat/
+-- blocks/
|   +-- algorithms/
|   |   +-- chunky-tri-mesh.ts
|   |   +-- convex-hull.ts
|   |   +-- index.ts
|   |   +-- merge-positions-and-indices.ts
|   +-- search/
|   |   +-- flood-fill-nav-mesh.ts
|   |   +-- index.ts
|   +-- index.ts
+-- docs/
|   +-- snippets/
|   |   +-- blocks.ts
|   |   +-- package.json
|   |   +-- solo-navmesh.ts
|   |   +-- threejs.ts
|   |   +-- tsconfig.json
|   +-- 1-whats-a-navmesh.png
|   +-- 2-1-navmesh-gen-input.png
|   +-- 2-10-navmesh-gen-detail-mesh.png
|   +-- 2-2-navmesh-gen-walkable-triangles.png
|   +-- 2-3-navmesh-gen-heightfield.png
|   +-- 2-4-navmesh-gen-compact-heightfield.png
|   +-- 2-5-navmesh-gen-compact-heightfield-distances.png
|   +-- 2-6-navmesh-gen-compact-heightfield-regions.png
|   +-- 2-7-navmesh-gen-raw-contours.png
|   +-- 2-8-navmesh-gen-simplified-contours.png
|   +-- 2-9-navmesh-gen-poly-mesh.png
|   +-- build.js
|   +-- cover.png
|   +-- README.template.md
+-- examples/
|   +-- public/
|   |   +-- models/
|   |   |   +-- bridges.blend
|   |   |   +-- bridges.glb
|   |   |   +-- cat.gltf
|   |   |   +-- cat.md
|   |   |   +-- character.glb
|   |   |   +-- crowd-simulation-stress-test.blend
|   |   |   +-- crowd-simulation-stress-test.blend1
|   |   |   +-- crowd-simulation-stress-test.glb
|   |   |   +-- doors-and-keys.blend
|   |   |   +-- doors-and-keys.glb
|   |   |   +-- doors-and-keys.md
|   |   |   +-- dungeon.gltf
|   |   |   +-- game-level.blend
|   |   |   +-- game-level.glb
|   |   |   +-- lowpoly__fps__tdm__game__map_by_resoforge.blend
|   |   |   +-- lowpoly__fps__tdm__game__map_by_resoforge.glb
|   |   |   +-- lowpoly__fps__tdm__game__map_by_resoforge.md
|   |   |   +-- nav-test.glb
|   |   |   +-- proto-level.glb
|   |   |   +-- tower-big.glb
|   |   +-- screenshots/
|   |   |   +-- example-area-costs.png
|   |   |   +-- example-area-filters.png
|   |   |   +-- example-chunky-tri-mesh.png
|   |   |   +-- example-crowd-simulation-stress-test.png
|   |   |   +-- example-crowd-simulation.png
|   |   |   +-- example-custom-gltf-navmesh.png
|   |   |   +-- example-custom-navmesh-generation.png
|   |   |   +-- example-doors-and-keys.png
|   |   |   +-- example-dynamic-navmesh.png
|   |   |   +-- example-dynamic-obstacles.png
|   |   |   +-- example-find-diverse-paths.png
|   |   |   +-- example-find-nearest-poly.png
|   |   |   +-- example-find-node-path.png
|   |   |   +-- example-find-path.png
|   |   |   +-- example-find-random-point-around-circle.png
|   |   |   +-- example-find-random-point.png
|   |   |   +-- example-find-shortest-paths.png
|   |   |   +-- example-find-smooth-path.png
|   |   |   +-- example-find-straight-path.png
|   |   |   +-- example-flood-fill-pruning.png
|   |   |   +-- example-flow-field-pathfinding.png
|   |   |   +-- example-fps-dynamic-navmesh.png
|   |   |   +-- example-mark-compact-heightfield-areas.png
|   |   |   +-- example-move-along-surface.png
|   |   |   +-- example-multiple-agent-sizes.png
|   |   |   +-- example-navmesh-constrained-character-controller.png
|   |   |   +-- example-off-mesh-connections.png
|   |   |   +-- example-rasterize-filled-volume.png
|   |   |   +-- example-raycast.png
|   |   |   +-- example-solo-navmesh.png
|   |   |   +-- example-tiled-navmesh.png
|   |   |   +-- example-upload-model.png
|   +-- src/
|   |   +-- common/
|   |   |   +-- example-base.ts
|   |   |   +-- flag.ts
|   |   |   +-- flow-field.ts
|   |   |   +-- load-gltf.ts
|   |   +-- example-area-costs.ts
|   |   +-- example-area-filters.ts
|   |   +-- example-chunky-tri-mesh.ts
|   |   +-- example-crowd-simulation-stress-test.ts
|   |   +-- example-crowd-simulation.ts
|   |   +-- example-custom-gltf-navmesh.ts
|   |   +-- example-custom-navmesh-generation.ts
|   |   +-- example-doors-and-keys.ts
|   |   +-- example-dynamic-navmesh.ts
|   |   +-- example-dynamic-obstacles.ts
|   |   +-- example-find-diverse-paths.ts
|   |   +-- example-find-nearest-poly.ts
|   |   +-- example-find-node-path.ts
|   |   +-- example-find-path.ts
|   |   +-- example-find-random-point-around-circle.ts
|   |   +-- example-find-random-point.ts
|   |   +-- example-find-shortest-paths.ts
|   |   +-- example-find-smooth-path.ts
|   |   +-- example-find-straight-path.ts
|   |   +-- example-flood-fill-pruning.ts
|   |   +-- example-flow-field-pathfinding.ts
|   |   +-- example-fps-dynamic-navmesh.ts
|   |   +-- example-mark-compact-heightfield-areas.ts
|   |   +-- example-move-along-surface.ts
|   |   +-- example-multiple-agent-sizes.ts
|   |   +-- example-navmesh-constrained-character-controller.ts
|   |   +-- example-off-mesh-connections.ts
|   |   +-- example-rasterize-filled-volume.ts
|   |   +-- example-raycast.ts
|   |   +-- example-solo-navmesh.ts
|   |   +-- example-tiled-navmesh.ts
|   |   +-- example-upload-model.ts
|   |   +-- example.css
|   |   +-- examples.json
|   +-- example-*.html (interactive examples)
|   +-- index.html
|   +-- package.json
|   +-- tsconfig.json
|   +-- vite.config.ts
+-- src/
|   +-- generate/
|   |   +-- build-context.ts
|   |   +-- common.ts
|   |   +-- compact-heightfield-regions.ts
|   |   +-- compact-heightfield.ts
|   |   +-- contour-set.ts
|   |   +-- heightfield.ts
|   |   +-- index.ts
|   |   +-- input-triangle-mesh.ts
|   |   +-- nav-mesh-tile.ts
|   |   +-- poly-mesh-detail.ts
|   |   +-- poly-mesh.ts
|   |   +-- poly-neighbours.ts
|   +-- query/
|   |   +-- bv-tree.ts
|   |   +-- find-path.ts
|   |   +-- find-smooth-path.ts
|   |   +-- find-straight-path.ts
|   |   +-- index.ts
|   |   +-- local-neighbourhood.ts
|   |   +-- nav-mesh-api.ts
|   |   +-- nav-mesh-search.ts
|   |   +-- nav-mesh.ts
|   |   +-- node.ts
|   +-- debug.ts
|   +-- geometry.ts
|   +-- index-pool.ts
|   +-- index.ts
+-- three/
|   +-- debug.ts
|   +-- get-positions-and-indices.ts
|   +-- index.ts
+-- tst/
|   +-- chunky-tri-mesh.test.ts
|   +-- compact-heightfield.test.ts
|   +-- geometry.test.ts
|   +-- heightfield.test.ts
|   +-- move-along-surface.test.ts
|   +-- nav-mesh-api.test.ts
|   +-- node-graph.test.ts
|   +-- node.test.ts
|   +-- path-corridor.test.ts
+-- website/
|   +-- public/
|   +-- src/
|   +-- build.sh
|   +-- index.html
|   +-- package.json
|   +-- tsconfig.json
|   +-- vite.config.ts
+-- .gitignore
+-- biome.json
+-- CHANGELOG.md
+-- CONTRIBUTING.md
+-- LICENSE
+-- package.json
+-- pnpm-lock.yaml
+-- pnpm-workspace.yaml
+-- README.md
+-- rollup.config.mjs
+-- tsconfig.json
```
