# leaflet-ohm-patches

OHM Leaflet files that override upstream openstreetmap-website versions. Kept separate to avoid merge conflicts on upstream pulls.

## Files

- `src/leaflet.map.js` — base map, layer switching
- `src/leaflet.layers.js` — layer config UI
- `src/leaflet.maplibre.js` — MapLibre GL bridge
- `src/leaflet.maptiler.js` — MapTiler vector layer
- `src/leaflet.shortbread.js` — Shortbread schema layer
- `src/leaflet.locate.js` — geolocation control

## Usage

`ohm-deploy` Dockerfile clones this repo and overwrites `app/assets/javascripts/` before `assets:precompile`:

```dockerfile
ENV LEAFLET_OHM_PATCHES_SHA=<commit-hash>
RUN git clone https://github.com/OpenHistoricalMap/leaflet-ohm-patches.git /tmp/patches && \
    cd /tmp/patches && git checkout $LEAFLET_OHM_PATCHES_SHA && \
    cp src/*.js /var/www/app/assets/javascripts/
```

Local dev — mount as volume:

```yaml
volumes:
  - /path/to/leaflet-ohm-patches/src:/var/www/app/assets/javascripts:ro
```


## Source for these files

Initial copy from `OpenHistoricalMap/ohm-website` `staging` @ `6dc7d515a60b70a27f90e0e8d333df645e37e9a8`.
