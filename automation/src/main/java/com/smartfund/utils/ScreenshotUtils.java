package com.smartfund.utils;

import com.smartfund.config.ConfigReader;
import com.smartfund.drivers.DriverManager;
import org.apache.commons.io.FileUtils;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.WebDriver;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;

public class ScreenshotUtils {

    public static String captureScreenshot(String testName) {
        String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss_SSS").format(new Date());
        String fileName = testName + "_" + timestamp + ".png";
        String dir = ConfigReader.getProperty("screenshot.dir");
        if (dir.isEmpty()) dir = "target/TestResults/Screenshots/";

        File targetDir = new File(dir);
        if (!targetDir.exists()) {
            targetDir.mkdirs();
        }

        String filePath = dir + fileName;
        WebDriver driver = DriverManager.getDriver();

        if (driver != null && driver instanceof TakesScreenshot) {
            try {
                File src = ((TakesScreenshot) driver).getScreenshotAs(OutputType.FILE);
                File dest = new File(filePath);
                FileUtils.copyFile(src, dest);
                return filePath;
            } catch (Exception e) {
                System.err.println("Failed to capture screenshot: " + e.getMessage());
            }
        }
        return filePath;
    }
}
