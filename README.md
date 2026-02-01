# Crispy Website

Minimalist black and white landing page for Crispy.

## Development

Simply open `index.html` in a browser. No build step required.

## Features

- **Auto-updating version**: Displays latest release version using GitHub API
- **Direct download links**: All buttons link to `github.com/sleep3r/crispy/releases/latest`
- **Release automation**: GitHub Action generates `release-info.json` on each release

## Release Automation

When a new release is published, the `update-website-release.yml` workflow:
1. Fetches release metadata from GitHub API
2. Generates `release-info.json` with version, assets, and URLs
3. Commits and pushes to repository

The website reads this JSON and displays the latest version. If the JSON is missing, it falls back to fetching directly from GitHub API.

## Deployment

Can be deployed to:
- **GitHub Pages** (recommended - auto-deploys from main branch)
- Netlify
- Vercel
- Cloudflare Pages
- Any static hosting

### GitHub Pages Setup

1. Go to repository Settings → Pages
2. Source: Deploy from a branch
3. Branch: `main`, folder: `/crispy-site`
4. Save

Site will be available at: `https://sleep3r.github.io/crispy/`

## TODO

- [x] Add real screenshot
- [x] Update download links to actual releases
- [x] Add GitHub Action for release automation
- [ ] Add favicon
- [ ] Consider adding analytics (privacy-friendly)
- [ ] Add "Star on GitHub" badge
