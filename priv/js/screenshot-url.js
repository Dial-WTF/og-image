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
  let file;

  // Validate URL
  if (!url || typeof url !== "string" || url.trim() === "") {
    throw new Error("Invalid URL provided");
  }

  // Ensure URL has a protocol
  let validUrl = url.trim();
  if (!validUrl.startsWith("http://") && !validUrl.startsWith("https://")) {
    validUrl = "https://" + validUrl;
  }

  const browser = await core.launch({
    executablePath,
    headless: true,
    args: [
      "--disable-dev-shm-usage",
      "--disable-setuid-sandbox",
      "--no-sandbox",
      "--enable-webgl",
      "--use-gl=swiftshader",
      "--ignore-gpu-blacklist",
      "--ignore-gpu-blocklist",
    ],
  });

  try {
    const page = await browser.newPage();

    // Set the viewport size to match standard open graph image cards
    await page.setViewport({ width: 1200, height: 630 });

    // Navigate to the URL with extended timeout for slow-loading sites
    await page.goto(validUrl, {
      waitUntil: "networkidle0",
      timeout: 60000, // Increased to 60 seconds for slow sites
    });

    // Wait for fonts to load
    await page.evaluate(async () => {
      await document.fonts.ready;
    });

    // Wait for images to load
    await page.evaluate(async () => {
      const selectors = Array.from(document.querySelectorAll("img"));
      await Promise.all(
        selectors.map((img) => {
          if (img.complete) {
            if (img.naturalHeight !== 0) return;
            // Image failed, but don't throw - just continue
            return Promise.resolve();
          }
          return new Promise((resolve) => {
            img.addEventListener("load", resolve);
            img.addEventListener("error", resolve); // Don't fail on image errors
            // Timeout after 5 seconds per image
            setTimeout(resolve, 5000);
          });
        })
      );
    });

    // Wait for any lazy-loaded content or animations
    await page.waitForTimeout(2000);

    let screenshotOptions = {
      type: "png",
      encoding: "base64",
    };

    // If a selector is provided, wait for it and screenshot just that element
    if (selector && selector !== null && selector !== undefined && selector !== "") {
      try {
        // Wait for selector to be visible
        await page.waitForSelector(selector, { timeout: 10000, visible: true });
        
        // Get the element and its bounding box
        const element = await page.$(selector);
        if (!element) {
          // If element not found, just screenshot the whole page instead of failing
          console.warn(`Element with selector "${selector}" not found, screenshotting full page`);
        } else {
          const boundingBox = await element.boundingBox();
          if (!boundingBox) {
            console.warn(`Element with selector "${selector}" has no bounding box, screenshotting full page`);
          } else {
            screenshotOptions.clip = boundingBox;
          }
        }
      } catch (err) {
        // If selector fails or times out, just screenshot the whole page
        console.warn(`Error with selector "${selector}": ${err.message}, screenshotting full page`);
      }
    }

    // Take the screenshot
    file = await page.screenshot(screenshotOptions);

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
