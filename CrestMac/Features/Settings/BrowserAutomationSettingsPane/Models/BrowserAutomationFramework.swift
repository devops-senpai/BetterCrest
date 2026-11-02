import Foundation

/// A testing framework that drives Arma's Chromium engine, and how a person
/// connects it: the code or settings that reach the DevTools port Arma
/// opens on this Mac.
struct BrowserAutomationFramework: Identifiable, Sendable {
    // MARK: - Variables

    let id: String
    let name: String
    /// The language or place the setup goes.
    let language: String
    /// One line on how it connects.
    let summary: LocalizedStringResource
    /// The setup, for port `port` and ChromeDriver `driver`.
    let setup: @Sendable (_ port: Int, _ driver: String) -> String

    // MARK: - Static Variables

    static let puppeteer = BrowserAutomationFramework(
        id: "puppeteer", name: "Puppeteer", language: "JavaScript",
        summary: "Connects to the running browser."
    ) { port, _ in
        """
        import puppeteer from "puppeteer-core";

        const browser = await puppeteer.connect({
          browserURL: "http://127.0.0.1:\(port)",
          defaultViewport: null,
        });
        const page = await browser.newPage();
        await page.goto("https://example.com");
        await browser.disconnect(); // browser.close() would quit Arma
        """
    }

    static let playwright = BrowserAutomationFramework(
        id: "playwright", name: "Playwright", language: "JavaScript",
        summary: "Connects over the Chrome DevTools Protocol; Chromium only."
    ) { port, _ in
        """
        import { chromium } from "playwright-core";

        const browser = await chromium.connectOverCDP("http://127.0.0.1:\(port)");
        const context = browser.contexts()[0];
        const page = await context.newPage();
        await page.goto("https://example.com");
        """
    }

    static let selenium = BrowserAutomationFramework(
        id: "selenium", name: "Selenium", language: "Python",
        summary: "Attaches ChromeDriver to the running browser."
    ) { port, driver in
        """
        # ChromeDriver \(driver), the version of Arma's Chromium.
        # ChromeDriver attaches to an open page; with "Only tabs it opens",
        # open one first: curl -X PUT http://127.0.0.1:\(port)/json/new
        from selenium import webdriver

        options = webdriver.ChromeOptions()
        options.debugger_address = "127.0.0.1:\(port)"
        driver = webdriver.Chrome(options=options)
        driver.get("https://example.com")
        """
    }

    static let webdriverIO = BrowserAutomationFramework(
        id: "webdriverio", name: "WebdriverIO", language: "wdio.conf.js",
        summary: "Attaches ChromeDriver to the running browser."
    ) { port, driver in
        """
        // ChromeDriver \(driver), the version of Arma's Chromium. With "Only tabs
        // it opens", open a page first: curl -X PUT http://127.0.0.1:\(port)/json/new
        capabilities: [{
          browserName: "chrome",
          "goog:chromeOptions": { debuggerAddress: "127.0.0.1:\(port)" },
        }],
        """
    }

    static let katalon = BrowserAutomationFramework(
        id: "katalon", name: "Katalon", language: "Project Settings",
        summary: "Attaches its Chrome driver to the running browser."
    ) { port, driver in
        """
        Project › Settings › Desired Capabilities › WebUI › Chrome
          goog:chromeOptions   Dictionary
            debuggerAddress    String   127.0.0.1:\(port)

        Tools › Update WebDrivers › Chrome to ChromeDriver \(driver).
        """
    }

    static let testCafe = BrowserAutomationFramework(
        id: "testcafe", name: "TestCafe", language: "Terminal",
        summary: "Runs tests in an Arma tab through TestCafe's remote browser."
    ) { _, _ in
        """
        npx testcafe remote tests/
        # Open the address it prints in an Arma tab of the automation profile.
        """
    }

    /// Every framework the page offers, in the order it lists them.
    static let all: [BrowserAutomationFramework] = [
        playwright, puppeteer, selenium, webdriverIO, katalon, testCafe,
    ]
}
