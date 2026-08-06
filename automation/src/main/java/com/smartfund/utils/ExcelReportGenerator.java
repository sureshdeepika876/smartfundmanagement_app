package com.smartfund.utils;

import com.smartfund.models.TestResultModel;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.File;
import java.io.FileOutputStream;
import java.util.List;
import java.util.stream.Collectors;

public class ExcelReportGenerator {

    public static void generateReports(List<TestResultModel> testResults, String outputDir) {
        File dir = new File(outputDir);
        if (!dir.exists()) dir.mkdirs();

        generateMainReport(testResults, new File(dir, "Automation_Test_Report.xlsx"));
        generateFilteredReport(testResults.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).collect(Collectors.toList()),
                new File(dir, "Passed_Test_Cases.xlsx"), "Passed Tests");
        generateFilteredReport(testResults.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).collect(Collectors.toList()),
                new File(dir, "Failed_Test_Cases.xlsx"), "Failed Tests");
        generateSummaryWorkbook(testResults, new File(dir, "Execution_Summary.xlsx"));
    }

    private static void generateMainReport(List<TestResultModel> results, File outputFile) {
        try (Workbook workbook = new XSSFWorkbook()) {
            // Sheet 1: Executed Test Cases
            Sheet sheet1 = workbook.createSheet("Executed Test Cases");
            createHeaderRow(sheet1, new String[]{"Test ID", "Module", "Test Name", "Priority", "Status", "Execution Time (s)", "Steps", "Expected Result", "Actual Result"});
            int rowIdx = 1;
            for (TestResultModel t : results) {
                Row row = sheet1.createRow(rowIdx++);
                row.createCell(0).setCellValue(t.getTestId());
                row.createCell(1).setCellValue(t.getModule());
                row.createCell(2).setCellValue(t.getTestName());
                row.createCell(3).setCellValue(t.getPriority());
                row.createCell(4).setCellValue(t.getStatus());
                row.createCell(5).setCellValue(t.getExecutionTimeSeconds());
                row.createCell(6).setCellValue(t.getSteps());
                row.createCell(7).setCellValue(t.getExpectedResult());
                row.createCell(8).setCellValue(t.getActualResult());
            }

            // Sheet 2: Passed Tests
            Sheet sheet2 = workbook.createSheet("Passed Tests");
            populateFilteredSheet(sheet2, results.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).collect(Collectors.toList()));

            // Sheet 3: Failed Tests
            Sheet sheet3 = workbook.createSheet("Failed Tests");
            populateFilteredSheet(sheet3, results.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).collect(Collectors.toList()));

            // Sheet 4: Skipped Tests
            Sheet sheet4 = workbook.createSheet("Skipped Tests");
            populateFilteredSheet(sheet4, results.stream().filter(t -> "SKIPPED".equalsIgnoreCase(t.getStatus())).collect(Collectors.toList()));

            // Sheet 5: Execution Metrics
            Sheet sheet5 = workbook.createSheet("Execution Metrics");
            long passed = results.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).count();
            long failed = results.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).count();
            long skipped = results.stream().filter(t -> "SKIPPED".equalsIgnoreCase(t.getStatus())).count();
            long total = results.size();
            double passRate = total > 0 ? ((double) passed / total) * 100.0 : 0.0;

            createHeaderRow(sheet5, new String[]{"Metric", "Value"});
            String[][] metricsData = {
                {"Total Test Cases", String.valueOf(total)},
                {"Executed", String.valueOf(total)},
                {"Passed", String.valueOf(passed)},
                {"Failed", String.valueOf(failed)},
                {"Skipped", String.valueOf(skipped)},
                {"Pass Percentage", String.format("%.2f%%", passRate)}
            };
            for (int i = 0; i < metricsData.length; i++) {
                Row r = sheet5.createRow(i + 1);
                r.createCell(0).setCellValue(metricsData[i][0]);
                r.createCell(1).setCellValue(metricsData[i][1]);
            }

            // Sheet 6: Defect Summary
            Sheet sheet6 = workbook.createSheet("Defect Summary");
            createHeaderRow(sheet6, new String[]{"Test ID", "Module", "Failure Reason", "Screenshot Path"});
            int defectIdx = 1;
            for (TestResultModel t : results.stream().filter(res -> "FAILED".equalsIgnoreCase(res.getStatus())).collect(Collectors.toList())) {
                Row r = sheet6.createRow(defectIdx++);
                r.createCell(0).setCellValue(t.getTestId());
                r.createCell(1).setCellValue(t.getModule());
                r.createCell(2).setCellValue(t.getFailureReason() != null ? t.getFailureReason() : "N/A");
                r.createCell(3).setCellValue(t.getScreenshotPath() != null ? t.getScreenshotPath() : "N/A");
            }

            // Sheet 7: Pass Rate Summary
            Sheet sheet7 = workbook.createSheet("Pass Rate Summary");
            createHeaderRow(sheet7, new String[]{"Module", "Total", "Passed", "Failed", "Pass Rate (%)"});
            var moduleMap = results.stream().collect(Collectors.groupingBy(TestResultModel::getModule));
            int modIdx = 1;
            for (var entry : moduleMap.entrySet()) {
                String mod = entry.getKey();
                List<TestResultModel> list = entry.getValue();
                long modPassed = list.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).count();
                long modFailed = list.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).count();
                double modRate = list.size() > 0 ? ((double) modPassed / list.size()) * 100.0 : 0.0;
                Row r = sheet7.createRow(modIdx++);
                r.createCell(0).setCellValue(mod);
                r.createCell(1).setCellValue(list.size());
                r.createCell(2).setCellValue(modPassed);
                r.createCell(3).setCellValue(modFailed);
                r.createCell(4).setCellValue(String.format("%.2f", modRate));
            }

            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                workbook.write(fos);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void generateFilteredReport(List<TestResultModel> filtered, File outputFile, String sheetName) {
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet(sheetName);
            populateFilteredSheet(sheet, filtered);
            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                workbook.write(fos);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void generateSummaryWorkbook(List<TestResultModel> results, File outputFile) {
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet("Execution Summary");
            long passed = results.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).count();
            long failed = results.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).count();
            long skipped = results.stream().filter(t -> "SKIPPED".equalsIgnoreCase(t.getStatus())).count();
            long total = results.size();

            createHeaderRow(sheet, new String[]{"Summary Attribute", "Details"});
            String[][] data = {
                {"Execution Framework", "Appium E2E Automation Suite"},
                {"Target Platform", "Android (UiAutomator2)"},
                {"Total Executed", String.valueOf(total)},
                {"Passed Count", String.valueOf(passed)},
                {"Failed Count", String.valueOf(failed)},
                {"Skipped Count", String.valueOf(skipped)},
                {"Pass Percentage", String.format("%.2f%%", total > 0 ? ((double) passed / total) * 100.0 : 0)}
            };
            for (int i = 0; i < data.length; i++) {
                Row r = sheet.createRow(i + 1);
                r.createCell(0).setCellValue(data[i][0]);
                r.createCell(1).setCellValue(data[i][1]);
            }
            try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                workbook.write(fos);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void populateFilteredSheet(Sheet sheet, List<TestResultModel> list) {
        createHeaderRow(sheet, new String[]{"Test ID", "Module", "Test Name", "Priority", "Status", "Execution Time (s)"});
        int idx = 1;
        for (TestResultModel t : list) {
            Row r = sheet.createRow(idx++);
            r.createCell(0).setCellValue(t.getTestId());
            r.createCell(1).setCellValue(t.getModule());
            r.createCell(2).setCellValue(t.getTestName());
            r.createCell(3).setCellValue(t.getPriority());
            r.createCell(4).setCellValue(t.getStatus());
            r.createCell(5).setCellValue(t.getExecutionTimeSeconds());
        }
    }

    private static void createHeaderRow(Sheet sheet, String[] headers) {
        Row row = sheet.createRow(0);
        CellStyle style = sheet.getWorkbook().createCellStyle();
        Font font = sheet.getWorkbook().createFont();
        font.setBold(true);
        style.setFont(font);
        for (int i = 0; i < headers.length; i++) {
            Cell cell = row.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(style);
        }
    }
}
