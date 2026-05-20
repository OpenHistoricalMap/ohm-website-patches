# ohm-website-patches

OHM-specific overlays for files that conflict with upstream `openstreetmap-website` on merges. Keeps OHM customizations in a single repo so upstream pulls do not produce merge conflicts.

## Layout

The `overlays/` tree mirrors the `ohm-website` checkout. Every file under `overlays/` overwrites the same relative path in the target checkout when applied.

```
overlays/
├── app/
│   ├── abilities/        # ability.rb
│   ├── assets/           # javascripts, stylesheets, images
│   ├── controllers/      # site_controller, search query controllers
│   ├── helpers/          # ohm_helper, browse_helper, open_graph_helper
│   ├── models/           # social_link.rb
│   └── views/            # layouts, site/, export/
├── config/
│   ├── initializers/     # assets, content_security_policy, omniauth
│   ├── banners.yml
│   ├── layers.yml
│   ├── routes.rb
│   ├── settings.yml
│   └── example.settings.local.yml
└── lib/                  # auth.rb, date_range.rb, id.rb, map_layers.rb
```

Notable JS overrides under `overlays/app/assets/javascripts/`:

- `leaflet.map.js` — base map, layer switching
- `leaflet.layers.js` — layer config UI
- `leaflet.maplibre.js` — MapLibre GL bridge
- `leaflet.maptiler.js` — MapTiler vector layer
- `leaflet.shortbread.js` — Shortbread schema layer
- `leaflet.locate.js` — geolocation control
- `application.js` — asset manifest

## Usage

Apply overlays onto an `ohm-website` checkout with the helper script:

```bash
./scripts/apply.sh /path/to/ohm-website
```

Or set `OHM_WEBSITE_DIR` and call without args. The script copies every file under `overlays/` into the destination, preserving directory structure.

### Docker build

`ohm-deploy` Dockerfile clones this repo and applies overlays before `assets:precompile`:

```dockerfile
ENV OHM_PATCHES_SHA=<commit-hash>
RUN git clone https://github.com/OpenHistoricalMap/ohm-website-patches.git /tmp/patches && \
    cd /tmp/patches && git checkout $OHM_PATCHES_SHA && \
    ./scripts/apply.sh /var/www
```

### Local dev

Mount the overlays tree on top of the running container:

```yaml
volumes:
  - /path/to/ohm-website-patches/overlays/app:/var/www/app:ro
  - /path/to/ohm-website-patches/overlays/config:/var/www/config:ro
  - /path/to/ohm-website-patches/overlays/lib:/var/www/lib:ro
```

## Source for these files

Initial copy from `OpenHistoricalMap/ohm-website` `staging` @ `6dc7d515a60b70a27f90e0e8d333df645e37e9a8`.
