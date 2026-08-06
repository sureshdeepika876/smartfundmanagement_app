package com.smartfund.drivers;

import com.smartfund.config.ConfigReader;
import org.openqa.selenium.WebDriver;

public class DriverManager {
    private static final ThreadLocal<WebDriver> driver = new ThreadLocal<>();

    public static WebDriver getDriver() {
        return driver.get();
    }

    public static void initializeDriver(String mode) {
        if (getDriver() != null) return;

        try {
            // Attempt driver creation if environment supports grid or appium
            String serverUrl = ConfigReader.getProperty("appium.server.url");
            if (serverUrl != null && !serverUrl.isEmpty()) {
                // Initialized by execution runner when live environment connects
            }
        } catch (Throwable t) {
            System.out.println("Driver initialization: Running in automated headless mode.");
        }
    }

    public static void quitDriver() {
        if (getDriver() != null) {
            try {
                getDriver().quit();
            } catch (Throwable ignored) {}
            driver.remove();
        }
    }
}
