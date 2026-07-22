# Plant Diversity cover image provenance

## Asset record

- Creation date: 2026-07-18
- Provider/tool: OpenAI image generation (imagegen skill; model identifier not exposed by tool)
- Use: scientific-educational cover art for the unofficial NEON Plant Diversity Explorer
- Third-party source material: none
- Visual treatment: original editorial cut-paper / natural-history illustration, clearly illustrative rather than documentary photography
- Rights note: generated specifically for this project; use remains subject to the OpenAI account terms under which it was created. The underlying NEON data attribution and CC BY 4.0 terms are separate and are stated on the cover.

## Generation prompts

### Desktop source

The generation tool expanded this source brief; no longer tool-expanded prompt string was exposed:

> Use case scientific-educational; wide website hero; sophisticated editorial cut-paper field-guide illustration; North American dryland grassland/shrubland; four nested survey grains 1/10/100/400; native plants plus restrained clay introduced patch; negative space left 42%; no text/logos/people/animals/mascot/UI/watermark.

### Mobile source

> Create a separate mobile portrait website hero asset, 9:16 vertical composition, for a scientific educational web app about NEON plant diversity. Sophisticated editorial cut-paper field-guide illustration, clearly illustrative rather than photorealistic. A North American dryland grassland and shrubland field plot with four visibly nested survey quadrat frames suggesting 1, 10, 100, and 400 square metres. Varied native grasses, forbs, and shrubs with one restrained clay-orange patch suggesting introduced cover. Composition: generous calm cream-to-sage negative space across the upper 35 percent and upper-left for responsive headline text; nested quadrats and botanical detail concentrated in the lower half and lower-right; a clear visual path downward. Palette: muted sage, charcoal green, warm cream, ochre, and clay. Crisp layered paper edges, refined natural-history editorial craft, no fake documentary photography. No text, no labels, no numbers, no logos, no people, no animals, no mascot, no app UI, no watermark.

## Files and checksums

SHA-256 checksums:

| File | Dimensions | Purpose | SHA-256 |
|---|---:|---|---|
| `assets/plant-nested-quadrat-hero-v1-source.png` | 1774×887 | Original desktop source | `77e73fedf5ab741763d9efa50bf3b876239707ee32d1e2bdceb767b38245e814` |
| `assets/plant-nested-quadrat-hero-mobile-v1-source.png` | 941×1672 | Original mobile source | `a729f710a1580f89fc8db000c738321db7af487ad9a759f71a0445d427856f01` |
| `assets/cover-generated/plant-nested-quadrat-hero-v1.jpg` | 1774×887 | Optimized desktop cover derivative | `6f150f3949082ecefa0d94055d9ac7ff5e36701d73debb1d03d2dc8c39314825` |
| `assets/cover-generated/plant-nested-quadrat-hero-mobile-v1.jpg` | 941×1672 | Optimized mobile cover derivative | `8856dbee5ba5883da18b75d68e5dafde8ea8f14707160e4cf3f2c2352d870d38` |
| `assets/cover-generated/plant-social-card-v1.svg` | 1200×630 | Reproducible Living Poster social-card source | `897063dc84b8f6660792fcfffcf36f59980934e4bf7e1a6c3d1ba544fe46d1a0` |
| `og-image.png` | 1200×630 | Open Graph / Twitter social image | `0c3c9262ec1ab046137dd082626b94dee775271be8c58f6f3287bee97e30c3cb` |
| `www/assets/plant-nested-quadrat-hero-v1.jpg` | 1774×887 | Byte-identical in-app desktop poster image | `6f150f3949082ecefa0d94055d9ac7ff5e36701d73debb1d03d2dc8c39314825` |
| `www/assets/plant-nested-quadrat-hero-mobile-v1.jpg` | 941×1672 | Byte-identical in-app mobile poster image | `8856dbee5ba5883da18b75d68e5dafde8ea8f14707160e4cf3f2c2352d870d38` |

The JPEG cover derivatives use quality 84. The Pages and in-app Living Posters
reuse those derivatives; the in-app copies are byte-identical mirrors under
`www/assets/`. No new generative image operation was used for the Living Poster
revision. The social card is a local SVG composition using the unedited desktop
source, an accessibility title/description, and live vector text for the shared
hook and promise. It was rasterized locally and normalized to the exact 1200×630
social-card canvas. No generative edits were added during derivative processing.

## Accessibility text

- Hero image alt: “A cut-paper dryland plant community with four nested field quadrats extending from one square metre into the surrounding landscape.”
- Social image alt: “Cut-paper nested quadrats beside the words How much can one square hold?”

The visual contains no embedded labels. Survey-grain values, interpretation, caveats, and calls to action remain real HTML so they resize, translate, and remain available to assistive technology.
