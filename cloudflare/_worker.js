/**
 * Bootible - Cloudflare Pages Function
 *
 * Routes:
 *   /rog        -> targets/ally.ps1 (ROG Ally / Windows)
 *   /deck       -> targets/deck.sh  (Steam Deck / SteamOS)
 *   /docs       -> README rendered as HTML
 *   /           -> Landing page (browser) or help text (CLI)
 *   /*.png      -> Static assets (served by Pages)
 */

const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/gavinmcfall/bootible/main';

const ROUTES = {
  '/rog': {
    path: '/targets/ally.ps1',
    description: 'ROG Ally (Windows)',
  },
  '/deck': {
    path: '/targets/deck.sh',
    description: 'Steam Deck (SteamOS)',
  },
};

const README_URL = `${GITHUB_RAW_BASE}/README.md`;

const SCRIPT_CACHE_TTL = 60; // 1 minute (short for testing)

/**
 * Detect if request is from a browser (vs curl/PowerShell)
 */
function isBrowser(request) {
  const userAgent = request.headers.get('User-Agent') || '';
  const accept = request.headers.get('Accept') || '';
  return accept.includes('text/html') && userAgent.includes('Mozilla');
}

/**
 * Escape HTML special characters to prevent XSS
 */
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Sanitize URL to prevent javascript: and data: XSS attacks
 */
function sanitizeUrl(url) {
  const trimmed = url.trim().toLowerCase();
  if (trimmed.startsWith('javascript:') || trimmed.startsWith('data:') || trimmed.startsWith('vbscript:')) {
    return '#blocked';
  }
  return escapeHtml(url);
}

/**
 * Markdown to HTML converter
 */
function markdownToHtml(md) {
  let html = md;

  const codeBlocks = [];
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => {
    codeBlocks.push(`<pre><code class="language-${escapeHtml(lang)}">${escapeHtml(code)}</code></pre>`);
    return `__CODE_BLOCK_${codeBlocks.length - 1}__`;
  });

  const inlineCodes = [];
  html = html.replace(/`([^`]+)`/g, (_, code) => {
    inlineCodes.push(`<code>${escapeHtml(code)}</code>`);
    return `__INLINE_CODE_${inlineCodes.length - 1}__`;
  });

  html = html.replace(/^\|(.+)\|\n\|[-| :]+\|\n((?:\|.+\|\n?)+)/gm, (_, header, body) => {
    const headerCells = header.split('|').map(c => c.trim()).filter(Boolean);
    const headerRow = headerCells.map(c => `<th>${escapeHtml(c)}</th>`).join('');
    const bodyRows = body.trim().split('\n').map(row => {
      const cells = row.split('|').map(c => c.trim()).filter(Boolean);
      return `<tr>${cells.map(c => `<td>${escapeHtml(c)}</td>`).join('')}</tr>`;
    }).join('\n');
    return `<table><thead><tr>${headerRow}</tr></thead><tbody>${bodyRows}</tbody></table>`;
  });

  html = html.replace(/^> (.+)$/gm, '<blockquote>$1</blockquote>');
  html = html.replace(/<\/blockquote>\n<blockquote>/g, '\n');
  html = html.replace(/^---+$/gm, '<hr>');
  html = html.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_, alt, src) =>
    `<img src="${sanitizeUrl(src)}" alt="${escapeHtml(alt)}">`
  );
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, text, href) =>
    `<a href="${sanitizeUrl(href)}" target="_blank">${text}</a>`
  );
  html = html.replace(/^#### (.+)$/gm, '<h4>$1</h4>');
  html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');
  html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
  html = html.replace(/^(\s*)[-*] (.+)$/gm, '$1<li>$2</li>');
  html = html.replace(/((?:<li>.*<\/li>\n?)+)/g, '<ul>$1</ul>');
  html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');
  html = html.replace(/^(?!<[a-z]|__|\s*$)(.+)$/gm, '<p>$1</p>');

  codeBlocks.forEach((block, i) => {
    html = html.replace(`__CODE_BLOCK_${i}__`, block);
  });
  inlineCodes.forEach((code, i) => {
    html = html.replace(`__INLINE_CODE_${i}__`, code);
  });

  html = html.replace(/<p><\/p>/g, '');
  html = html.replace(/<p>\s*<\/p>/g, '');
  html = html.replace(/\n{3,}/g, '\n\n');

  return html;
}

/**
 * Generate docs page from README
 */
function getDocsPage(readmeHtml) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bootible Documentation</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  <style>
    :root {
      --bg-dark: #0d1117;
      --bg-card: #161b22;
      --accent: #58a6ff;
      --text-primary: #f0f6fc;
      --text-secondary: #8b949e;
      --border: #30363d;
      --success: #3fb950;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg-dark);
      color: var(--text-primary);
      line-height: 1.7;
      padding: 40px 20px;
    }
    .container { max-width: 800px; margin: 0 auto; }
    .back-link {
      display: inline-block;
      color: var(--accent);
      text-decoration: none;
      margin-bottom: 24px;
      font-size: 0.9rem;
    }
    .back-link:hover { text-decoration: underline; }
    h1, h2, h3, h4 { margin: 24px 0 12px; color: var(--text-primary); }
    h1 { font-size: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 8px; }
    h2 { font-size: 1.5rem; border-bottom: 1px solid var(--border); padding-bottom: 6px; }
    h3 { font-size: 1.25rem; }
    p { margin: 12px 0; color: var(--text-secondary); }
    a { color: var(--accent); }
    code {
      background: var(--bg-card);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'SF Mono', 'Fira Code', monospace;
      font-size: 0.9em;
    }
    pre {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
      overflow-x: auto;
      margin: 16px 0;
    }
    pre code { background: none; padding: 0; }
    ul, ol { margin: 12px 0; padding-left: 24px; color: var(--text-secondary); }
    li { margin: 6px 0; }
    strong { color: var(--text-primary); }
    table { width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 0.9rem; }
    th, td { border: 1px solid var(--border); padding: 10px 14px; text-align: left; }
    th { background: var(--bg-card); color: var(--text-primary); font-weight: 600; }
    td { color: var(--text-secondary); }
    tr:nth-child(even) td { background: rgba(22, 27, 34, 0.5); }
    blockquote {
      border-left: 4px solid var(--accent);
      background: var(--bg-card);
      margin: 16px 0;
      padding: 12px 20px;
      border-radius: 0 8px 8px 0;
      color: var(--text-secondary);
      font-style: italic;
    }
    hr { border: none; border-top: 1px solid var(--border); margin: 32px 0; }
    details {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      margin: 16px 0;
      padding: 12px 16px;
    }
    summary { cursor: pointer; color: var(--accent); font-weight: 500; }
    summary:hover { text-decoration: underline; }
    details[open] summary { margin-bottom: 12px; }
    img { max-width: 100%; height: auto; vertical-align: middle; }
    img[alt*="badge"], img[alt*="License"], img[alt*="shield"] { height: 20px; margin-right: 8px; }
  </style>
</head>
<body>
  <div class="container">
    <a href="/" class="back-link">← Back to Bootible</a>
    ${readmeHtml}
  </div>
</body>
</html>`;
}

/**
 * Generate plain text help for CLI clients
 */
function getPlainTextHelp() {
  return `Bootible - One-liner setup for gaming handhelds

Usage:

  Steam Deck:
    curl -fsSL https://bootible.dev/deck | bash

  ROG Ally X:
    irm https://bootible.dev/rog | iex

More info: https://github.com/gavinmcfall/bootible
`;
}

/**
 * Landing page HTML
 */
function getLandingPage() {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bootible - One-liner setup for gaming handhelds</title>
  <meta name="description" content="Bootible automates the setup of Steam Deck, ROG Ally X, and other gaming devices with a single command.">
  <link rel="icon" type="image/png" href="/favicon.png">
  <style>
    :root {
      --bg-dark: #0d1117;
      --bg-card: #161b22;
      --bg-card-hover: #1c2128;
      --accent: #58a6ff;
      --accent-glow: rgba(88, 166, 255, 0.3);
      --text-primary: #f0f6fc;
      --text-secondary: #8b949e;
      --text-muted: #6e7681;
      --border: #30363d;
      --success: #3fb950;
      --gradient-start: #1a1a2e;
      --gradient-end: #0d1117;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: linear-gradient(135deg, var(--gradient-start) 0%, var(--gradient-end) 100%);
      color: var(--text-primary);
      min-height: 100vh;
      line-height: 1.6;
    }
    .container { max-width: 900px; margin: 0 auto; padding: 40px 20px; }
    .hero { text-align: center; padding: 60px 0 40px; }
    .logo {
      width: 140px;
      height: 140px;
      margin-bottom: 24px;
      filter: drop-shadow(0 0 30px var(--accent-glow));
      animation: float 3s ease-in-out infinite;
    }
    @keyframes float {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-10px); }
    }
    .hero h1 {
      font-size: 3.5rem;
      font-weight: 700;
      margin-bottom: 16px;
      background: linear-gradient(135deg, var(--text-primary) 0%, var(--accent) 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .tagline { font-size: 1.4rem; color: var(--text-secondary); margin-bottom: 40px; }
    .callout {
      background: linear-gradient(135deg, rgba(88, 166, 255, 0.1) 0%, rgba(63, 185, 80, 0.1) 100%);
      border: 1px solid var(--accent);
      border-radius: 12px;
      padding: 16px 24px;
      margin-bottom: 40px;
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .callout-icon { font-size: 1.5rem; flex-shrink: 0; }
    .callout-content { flex: 1; }
    .callout-title { font-weight: 600; margin-bottom: 4px; }
    .callout-text { color: var(--text-secondary); font-size: 0.9rem; }
    .callout-link { color: var(--accent); text-decoration: none; font-weight: 500; white-space: nowrap; }
    .callout-link:hover { text-decoration: underline; }
    .devices { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 60px; }
    .device-card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
      transition: all 0.3s ease;
      position: relative;
      overflow: hidden;
    }
    .device-card::before {
      content: '';
      position: absolute;
      top: 0; left: 0; right: 0;
      height: 3px;
      background: linear-gradient(90deg, var(--accent), var(--success));
      opacity: 0;
      transition: opacity 0.3s ease;
    }
    .device-card:hover {
      background: var(--bg-card-hover);
      border-color: var(--accent);
      transform: translateY(-4px);
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    }
    .device-card:hover::before { opacity: 1; }
    .device-header { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
    .device-icon { width: 48px; height: 48px; flex-shrink: 0; object-fit: contain; }
    .device-info { flex: 1; }
    .device-name { font-size: 1.2rem; font-weight: 600; margin-bottom: 2px; }
    .device-name .variant { font-size: 0.75rem; font-weight: 400; color: var(--text-muted); }
    .device-platform { color: var(--text-muted); font-size: 0.8rem; }
    .command-wrapper { display: flex; flex-direction: column; gap: 8px; }
    .copy-btn {
      align-self: flex-end;
      background: var(--bg-dark);
      border: 1px solid var(--border);
      color: var(--text-secondary);
      padding: 4px 12px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.75rem;
      transition: all 0.2s ease;
    }
    .copy-btn:hover { background: var(--accent); color: var(--bg-dark); border-color: var(--accent); }
    .copy-btn.copied { background: var(--success); border-color: var(--success); color: var(--bg-dark); }
    .command-block {
      background: var(--bg-dark);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 12px 16px;
      font-family: 'SF Mono', 'Fira Code', 'Consolas', monospace;
      font-size: 0.85rem;
      overflow-x: auto;
    }
    .command-block code { color: var(--accent); white-space: nowrap; }
    .features { margin-bottom: 60px; }
    .features h2 { text-align: center; font-size: 2rem; margin-bottom: 32px; color: var(--text-primary); }
    .feature-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
    @media (max-width: 800px) { .feature-grid { grid-template-columns: repeat(2, 1fr); } }
    .feature {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 24px;
      text-align: center;
      transition: border-color 0.3s ease;
    }
    .feature:hover { border-color: var(--accent); }
    .feature-icon { font-size: 2rem; margin-bottom: 12px; }
    .feature-title { font-weight: 600; margin-bottom: 8px; }
    .feature-desc { color: var(--text-secondary); font-size: 0.9rem; }
    .info {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 32px;
      margin-bottom: 40px;
    }
    .info h3 { font-size: 1.3rem; margin-bottom: 16px; display: flex; align-items: center; gap: 10px; }
    .info p { color: var(--text-secondary); margin-bottom: 12px; }
    .info ul { list-style: none; padding-left: 0; }
    .info li { color: var(--text-secondary); padding: 8px 0; padding-left: 24px; position: relative; }
    .info li::before { content: '✓'; position: absolute; left: 0; color: var(--success); }
    footer { text-align: center; padding: 40px 0; border-top: 1px solid var(--border); }
    footer a { color: var(--accent); text-decoration: none; transition: opacity 0.2s ease; }
    footer a:hover { opacity: 0.8; }
    .github-link {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--bg-card);
      border: 1px solid var(--border);
      padding: 12px 24px;
      border-radius: 8px;
      color: var(--text-primary);
      font-weight: 500;
      transition: all 0.2s ease;
    }
    .github-link:hover { background: var(--bg-card-hover); border-color: var(--accent); }
    .github-link svg { width: 20px; height: 20px; fill: currentColor; }
    @media (max-width: 700px) { .devices { grid-template-columns: 1fr; } }
    @media (max-width: 600px) {
      .hero h1 { font-size: 2.5rem; }
      .tagline { font-size: 1.1rem; }
      .logo { width: 100px; height: 100px; }
    }
  </style>
</head>
<body>
  <div class="container">
    <section class="hero">
      <img src="/logo.png" alt="Bootible Logo" class="logo">
      <h1>Bootible</h1>
      <p class="tagline">One-liner setup for gaming handhelds</p>
    </section>

    <div class="callout">
      <span class="callout-icon">📖</span>
      <div class="callout-content">
        <div class="callout-title">New to Bootible?</div>
        <div class="callout-text">Read the documentation to understand what gets installed and how to customize your setup.</div>
      </div>
      <a href="/docs" class="callout-link">Read the Docs →</a>
    </div>

    <section class="devices">
      <div class="device-card">
        <div class="device-header">
          <img class="device-icon" src="/steamdeck.png" alt="Steam Deck">
          <div class="device-info">
            <h3 class="device-name">Steam Deck</h3>
            <p class="device-platform">SteamOS / Arch Linux</p>
          </div>
        </div>
        <div class="command-wrapper">
          <button class="copy-btn" onclick="copyCommand(this, 'curl -fsSL https://bootible.dev/deck | bash')">Copy</button>
          <div class="command-block">
            <code>curl -fsSL https://bootible.dev/deck | bash</code>
          </div>
        </div>
      </div>

      <div class="device-card">
        <div class="device-header">
          <img class="device-icon" src="/rog.png" alt="ROG Ally">
          <div class="device-info">
            <h3 class="device-name">ROG Ally <span class="variant">(all variants)</span></h3>
            <p class="device-platform">Windows 11</p>
          </div>
        </div>
        <div class="command-wrapper">
          <button class="copy-btn" onclick="copyCommand(this, 'irm https://bootible.dev/rog | iex')">Copy</button>
          <div class="command-block">
            <code>irm https://bootible.dev/rog | iex</code>
          </div>
        </div>
      </div>
    </section>

    <section class="features">
      <h2>What You Get</h2>
      <div class="feature-grid">
        <div class="feature">
          <div class="feature-icon">🧩</div>
          <div class="feature-title">Apps & Tools</div>
          <div class="feature-desc">Discord, Spotify, browsers, and more</div>
        </div>
        <div class="feature">
          <div class="feature-icon">🎮</div>
          <div class="feature-title">Gaming</div>
          <div class="feature-desc">Steam, launchers, Decky Loader</div>
        </div>
        <div class="feature">
          <div class="feature-icon">📡</div>
          <div class="feature-title">Streaming</div>
          <div class="feature-desc">Moonlight, Chiaki, Sunshine</div>
        </div>
        <div class="feature">
          <div class="feature-icon">👾</div>
          <div class="feature-title">Emulation</div>
          <div class="feature-desc">EmuDeck, RetroArch</div>
        </div>
        <div class="feature">
          <div class="feature-icon">🔐</div>
          <div class="feature-title">Passwords</div>
          <div class="feature-desc">1Password, Bitwarden</div>
        </div>
        <div class="feature">
          <div class="feature-icon">🔄</div>
          <div class="feature-title">Cloud Sync</div>
          <div class="feature-desc">Save games, configs, dotfiles</div>
        </div>
        <div class="feature">
          <div class="feature-icon">🚀</div>
          <div class="feature-title">Optimization</div>
          <div class="feature-desc">Debloat, tweaks, performance</div>
        </div>
        <div class="feature">
          <div class="feature-icon">🌐</div>
          <div class="feature-title">Remote Access</div>
          <div class="feature-desc">SSH, Tailscale, RDP</div>
        </div>
      </div>
    </section>

    <section class="info">
      <h3>🛡️ Safe by Default</h3>
      <p>Bootible runs in <strong>dry-run mode</strong> by default. Preview all changes before applying.</p>
      <ul>
        <li>Everything is opt-in via config</li>
        <li>Creates restore points (Windows)</li>
        <li>Private config stays in your own repo</li>
        <li>Open source and auditable</li>
      </ul>
    </section>

    <footer>
      <a href="https://github.com/gavinmcfall/bootible" class="github-link">
        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
        </svg>
        View on GitHub
      </a>
    </footer>
  </div>

  <script>
    function copyCommand(btn, text) {
      navigator.clipboard.writeText(text).then(() => {
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = 'Copy';
          btn.classList.remove('copied');
        }, 2000);
      });
    }
  </script>
</body>
</html>`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle root path - landing page for browsers, help text for CLI
    if (path === '/' || path === '') {
      if (isBrowser(request)) {
        return new Response(getLandingPage(), {
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'public, max-age=3600',
          },
        });
      }
      return new Response(getPlainTextHelp(), {
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      });
    }

    // Handle docs page - fetch README from GitHub and render as HTML
    if (path === '/docs') {
      try {
        const response = await fetch(README_URL);

        if (!response.ok) {
          return new Response('Failed to load documentation', {
            status: 502,
            headers: { 'Content-Type': 'text/plain' },
          });
        }

        const markdown = await response.text();
        const html = markdownToHtml(markdown);

        return new Response(getDocsPage(html), {
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': `public, max-age=${SCRIPT_CACHE_TTL}`,
          },
        });
      } catch (error) {
        return new Response(`Error loading docs: ${error}`, {
          status: 502,
          headers: { 'Content-Type': 'text/plain' },
        });
      }
    }

    // Handle script routes (proxy from GitHub)
    const route = ROUTES[path];
    if (route) {
      // Add cache-buster to bypass GitHub's raw CDN cache
      const cacheBuster = Date.now();
      const scriptUrl = `${GITHUB_RAW_BASE}${route.path}?cb=${cacheBuster}`;

      try {
        const response = await fetch(scriptUrl, {
          headers: { 'Cache-Control': 'no-cache' },
        });

        if (!response.ok) {
          return new Response(`Failed to fetch script: ${response.status}`, {
            status: 502,
            headers: { 'Content-Type': 'text/plain' },
          });
        }

        const script = await response.text();

        return new Response(script, {
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'X-Bootible-Device': route.description,
          },
        });
      } catch (error) {
        return new Response(`Error fetching script: ${error}`, {
          status: 502,
          headers: { 'Content-Type': 'text/plain' },
        });
      }
    }

    // Static assets - let Pages serve them
    return env.ASSETS.fetch(request);
  },
};
