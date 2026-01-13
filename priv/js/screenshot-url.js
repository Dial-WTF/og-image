const core = require("puppeteer-core");
const fs = require("fs");
const os = require("node:os");

const executablePath =
  process.platform === "win32"
    ? "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
    : process.platform === "linux"
    ? "/usr/bin/google-chrome"
    : "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

/**
 * Takes a screenshot of a URL, optionally screenshotting just a specific element.
 *
 * @param {string} url - The URL to screenshot.
 * @param {string} [selector] - Optional CSS selector to screenshot just that element.
 * @returns a Base64 encoded string of the screenshot.
 */
async function screenshotUrl(url, selector) {
  selector = selector || null;
  const width = 1200;
  const height = 630;
  const waitTime = 1000;

  const browser = await core.launch({
    executablePath,
    headless: true,
    args: [
      "--disable-gpu",
      "--disable-dev-shm-usage",
      "--disable-setuid-sandbox",
      "--no-sandbox",
    ],
  });

  try {
    const page = await browser.newPage();

    // Set the viewport size
    await page.setViewport({ width, height });

    // Navigate to the URL
    await page.goto(url, {
      waitUntil: "networkidle0",
      timeout: 30000,
    });

    // Wait a bit for any animations/transitions
    await page.waitForTimeout(waitTime);

    // Wait for fonts to load
    await page.evaluate(async () => {
      await document.fonts.ready;
    });

    let screenshotOptions = {
      type: "png",
      encoding: "base64",
    };

    // If a selector is provided, screenshot just that element
    if (selector) {
      const element = await page.$(selector);
      if (!element) {
        throw new Error(`Element with selector "${selector}" not found`);
      }
      screenshotOptions.clip = await element.boundingBox();
    }

    // Take the screenshot
    const file = await page.screenshot(screenshotOptions);

    await page.close();
  } finally {
    await browser.close();
  }

  // Clean up puppeteer profiles
  try {
    deletePuppeteerProfiles();
  } catch {}

  return file;
}

/**
 * Delete puppeteer profiles from temp directory to free up space
 * See: https://github.com/puppeteer/puppeteer/issues/6414
 */
function deletePuppeteerProfiles() {
  const tmpdir = os.tmpdir();

  fs.readdirSync(tmpdir).forEach((file) => {
    if (file.startsWith("puppeteer_dev_chrome_profile")) {
      fs.rmSync(`${tmpdir}/${file}`, { recursive: true, force: true });
    }
  });
}

module.exports = screenshotUrl;
