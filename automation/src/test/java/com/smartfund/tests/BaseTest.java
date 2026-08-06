package com.smartfund.tests;

import com.smartfund.config.ConfigReader;
import com.smartfund.drivers.DriverManager;
import com.smartfund.listeners.RetryAnalyzer;
import com.smartfund.listeners.TestListener;
import org.testng.ITestContext;
import org.testng.annotations.*;

@Listeners({TestListener.class})
public class BaseTest {

    @BeforeSuite
    public void beforeSuite() {
        System.out.println("Starting Enterprise E2E Test Suite...");
    }

    @BeforeMethod
    public void setUp(ITestContext context) {
        String mode = ConfigReader.getProperty("execution.mode");
        if (mode.isEmpty()) mode = "appium";
        DriverManager.initializeDriver(mode);
    }

    @AfterMethod
    public void tearDown() {
        DriverManager.quitDriver();
    }

    protected void setTestMetadata(ITestContext context, String testId, String module, String priority) {
        if (context != null && context.getCurrentXmlTest() != null) {
            context.setAttribute("testId", testId);
            context.setAttribute("module", module);
            context.setAttribute("priority", priority);
        }
    }
}
