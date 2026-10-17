import sharp from 'sharp';
import { readFile, writeFile } from 'node:fs/promises';

// Real SwiftUI render with deterministic sample services; no synthetic product UI.
const screenshot = await sharp(await readFile(new URL('../static/brand/panel-dark.png', import.meta.url)))
  .resize(335, 465).png().toBuffer();
const logo = await readFile(new URL('../static/brand/mark.svg', import.meta.url));
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
<defs>
  <radialGradient id="glow"><stop stop-color="#345b43" stop-opacity=".5"/><stop offset="1" stop-color="#0b1211" stop-opacity="0"/></radialGradient>
  <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0H0V40" fill="none" stroke="#91f4cc" stroke-opacity=".04"/></pattern>
  <clipPath id="panel"><rect x="775" y="88" width="335" height="465" rx="16"/></clipPath>
</defs>
<rect width="1200" height="630" fill="#0b1211"/>
<rect width="1200" height="630" fill="url(#grid)"/>
<ellipse cx="945" cy="300" rx="430" ry="430" fill="url(#glow)"/>
<image x="70" y="60" width="48" height="48" href="data:image/svg+xml;base64,${logo.toString('base64')}"/>
<g font-family="Arial, Helvetica, sans-serif">
<text x="132" y="93" fill="#eff6f0" font-size="30" font-weight="700">LocalStack</text>
<text x="72" y="205" fill="#83ae94" font-size="12" letter-spacing="2">A LITTLE ORDER FOR YOUR LOCALHOST.</text>
<text x="68" y="281" fill="#eff6f0" font-size="62" font-weight="700" letter-spacing="-2">Your localhost.</text>
<text x="68" y="354" fill="#91f4cc" font-size="62" font-weight="700" letter-spacing="-2">All in one place.</text>
<text x="72" y="408" fill="#a3b6a9" font-size="18">A quiet menu bar for your local dev servers.</text>
<rect x="72" y="455" width="209" height="43" rx="7" fill="#91f4cc"/>
<text x="98" y="482" fill="#12291e" font-size="14" font-weight="700">Made for macOS 15+</text>
<text x="299" y="482" fill="#9daf9e" font-size="13">Free. Open source. Local.</text>
<text x="72" y="572" fill="#6f8e7b" font-size="13">localstack.pwp.sh</text>
</g>
<rect x="774" y="87" width="337" height="467" rx="17" fill="#202d24" stroke="#799583" stroke-opacity=".5"/>
<image x="775" y="88" width="335" height="465" clip-path="url(#panel)" href="data:image/png;base64,${screenshot.toString('base64')}"/>
</svg>`;
const png = await sharp(Buffer.from(svg)).png().toBuffer();
await writeFile(new URL('../static/brand/social.png', import.meta.url), png);
await writeFile(new URL('../../Resources/Brand/READMEHero.png', import.meta.url), png);
console.log('Generated website social image and README banner.');
