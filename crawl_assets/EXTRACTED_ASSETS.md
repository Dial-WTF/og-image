# Assets Extracted from staging.dial.wtf

## Images
- `images/dial-logo-transparent-bg.svg` - SVG logo with transparent background
- `images/dial_logo_transparent_v5.png` - PNG logo version 5 with transparent background

## CSS Files
- `css/main.css` - Main stylesheet from Next.js build
- `css/additional.css` - Additional stylesheet from Next.js build  
- `css/google-fonts-dm-sans.css` - Google Fonts DM Sans configuration

## Font
- **Font Family**: DM Sans (from Google Fonts)
  - Weights: 400 (regular), 500 (medium), 700 (bold)
  - URL: https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&display=swap

## Key Design Elements

### Logo
- SVG format available: `/watermarks/dial-logo-transparent-bg.svg`
- PNG format available: `/assets/dial_logo_transparent_v5.png`

### Gradient Text
Based on the home page design:
- Main heading: "Call. Text. Meet. From your wallet."
- "From your wallet." uses a gradient (cyan to green/emerald)
- Current implementation uses: `bg-gradient-to-r from-cyan-400 to-emerald-400 bg-clip-text text-transparent`

### Background
- Dark theme: `#0A0A0A` (near black)
- Light theme: white (`#FFFFFF`)

## Notes
- Site uses Next.js with Tailwind CSS (based on file structure)
- CSS files are minified/bundled, so specific gradient colors may need to be extracted from rendered styles
- Logo appears to be SVG-based for scalability
