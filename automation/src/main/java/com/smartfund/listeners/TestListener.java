package com.smartfund.listeners;

import com.smartfund.config.ConfigReader;
import com.smartfund.models.TestResultModel;
import com.smartfund.utils.*;
import org.testng.ITestContext;
import org.testng.ITestListener;
import org.testng.ITestResult;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class TestListener implements ITestListener {
    private static final List<TestResultModel> resultsList = Collections.synchronizedList(new ArrayList<>());

    public static List<TestResultModel> getResultsList() {
        return resultsList;
    }

    @Override
    public void onTestSuccess(ITestResult result) {
        recordResult(result, "PASSED", null);
    }

    @Override
    public void onTestFailure(ITestResult result) {
        String screenshot = ScreenshotUtils.captureScreenshot(result.getName());
        String reason = result.getThrowable() != null ? result.getThrowable().getMessage() : "Test execution failed";
        recordResult(result, "FAILED", reason, screenshot);
    }

    @Override
    public void onTestSkipped(ITestResult result) {
        recordResult(result, "SKIPPED", "Test skipped due to dependency or configuration");
    }

    private void recordResult(ITestResult result, String status, String failureReason) {
        recordResult(result, status, failureReason, null);
    }

    private void recordResult(ITestResult result, String status, String failureReason, String screenshotPath) {
        String testId = result.getAttribute("testId") != null ? (String) result.getAttribute("testId") : result.getName();
        String module = result.getAttribute("module") != null ? (String) result.getAttribute("module") : result.getTestClass().getRealClass().getSimpleName();
        String testName = result.getMethod().getDescription() != null ? result.getMethod().getDescription() : result.getName();
        String priority = result.getAttribute("priority") != null ? (String) result.getAttribute("priority") : "P2";
        double duration = (result.getEndMillis() - result.getStartMillis()) / 1000.0;
        if (duration <= 0) duration = 0.05;

        TestResultModel model = new TestResultModel(
            testId, module, testName, priority,
            "App Launched & Logged In", "Execute step flow", "Valid test dataset",
            "Expected condition fulfilled", status.equalsIgnoreCase("PASSED") ? "Condition satisfied" : failureReason,
            status, duration, failureReason, screenshotPath
        );
        resultsList.add(model);
        LoggingUtils.info("Completed: " + testId + " | Status: " + status);
    }

    @Override
    public void onFinish(ITestContext context) {
        LoggingUtils.info("Generating Excel, HTML, JSON, Summary, and Security audit reports for " + resultsList.size() + " test results...");
        String excelDir = ConfigReader.getProperty("excel.report.dir").isEmpty() ? "target/TestResults/Excel/" : ConfigReader.getProperty("excel.report.dir");
        String htmlDir = ConfigReader.getProperty("html.report.dir").isEmpty() ? "target/TestResults/HTML/" : ConfigReader.getProperty("html.report.dir");
        String jsonDir = ConfigReader.getProperty("json.report.dir").isEmpty() ? "target/TestResults/JSON/" : ConfigReader.getProperty("json.report.dir");
        String summaryDir = ConfigReader.getProperty("summary.report.dir").isEmpty() ? "target/TestResults/Summary/" : ConfigReader.getProperty("summary.report.dir");

        ExcelReportGenerator.generateReports(resultsList, excelDir);
        HtmlReportGenerator.generateReports(resultsList, htmlDir);
        JsonReportGenerator.generateReport(resultsList, jsonDir);
        MarkdownReportGenerator.generateSummary(resultsList, summaryDir);
        SecurityExcelGenerator.main(new String[0]);
    }
}
