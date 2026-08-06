package com.smartfund.models;

public class TestResultModel {
    private String testId;
    private String module;
    private String testName;
    private String priority;
    private String preconditions;
    private String steps;
    private String testData;
    private String expectedResult;
    private String actualResult;
    private String status; // PASSED, FAILED, SKIPPED, BLOCKED
    private double executionTimeSeconds;
    private String failureReason;
    private String screenshotPath;

    public TestResultModel(String testId, String module, String testName, String priority,
                           String preconditions, String steps, String testData,
                           String expectedResult, String actualResult, String status,
                           double executionTimeSeconds, String failureReason, String screenshotPath) {
        this.testId = testId;
        this.module = module;
        this.testName = testName;
        this.priority = priority;
        this.preconditions = preconditions;
        this.steps = steps;
        this.testData = testData;
        this.expectedResult = expectedResult;
        this.actualResult = actualResult;
        this.status = status;
        this.executionTimeSeconds = executionTimeSeconds;
        this.failureReason = failureReason;
        this.screenshotPath = screenshotPath;
    }

    public String getTestId() { return testId; }
    public String getModule() { return module; }
    public String getTestName() { return testName; }
    public String getPriority() { return priority; }
    public String getPreconditions() { return preconditions; }
    public String getSteps() { return steps; }
    public String getTestData() { return testData; }
    public String getExpectedResult() { return expectedResult; }
    public String getActualResult() { return actualResult; }
    public String getStatus() { return status; }
    public double getExecutionTimeSeconds() { return executionTimeSeconds; }
    public String getFailureReason() { return failureReason; }
    public String getScreenshotPath() { return screenshotPath; }

    public void setStatus(String status) { this.status = status; }
    public void setActualResult(String actualResult) { this.actualResult = actualResult; }
    public void setFailureReason(String failureReason) { this.failureReason = failureReason; }
    public void setScreenshotPath(String screenshotPath) { this.screenshotPath = screenshotPath; }
}
