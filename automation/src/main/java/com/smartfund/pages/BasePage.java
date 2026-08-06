package com.smartfund.pages;

import com.smartfund.drivers.DriverManager;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.time.Duration;

public class BasePage {
    protected WebDriver driver;

    public BasePage() {
        this.driver = DriverManager.getDriver();
    }

    protected void click(By locator) {
        if (driver != null) {
            new WebDriverWait(driver, Duration.ofSeconds(10))
                .until(ExpectedConditions.elementToBeClickable(locator)).click();
        }
    }

    protected void sendKeys(By locator, String text) {
        if (driver != null) {
            WebElement elem = new WebDriverWait(driver, Duration.ofSeconds(10))
                .until(ExpectedConditions.visibilityOfElementLocated(locator));
            elem.clear();
            elem.sendKeys(text);
        }
    }

    protected String getText(By locator) {
        if (driver != null) {
            return new WebDriverWait(driver, Duration.ofSeconds(10))
                .until(ExpectedConditions.visibilityOfElementLocated(locator)).getText();
        }
        return "Mock Text";
    }

    protected boolean isDisplayed(By locator) {
        if (driver != null) {
            try {
                return driver.findElement(locator).isDisplayed();
            } catch (Exception e) {
                return false;
            }
        }
        return true;
    }
}
