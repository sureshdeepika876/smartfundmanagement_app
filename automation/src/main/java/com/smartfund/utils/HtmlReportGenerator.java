package com.smartfund.utils;

import com.smartfund.models.TestResultModel;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;

public class HtmlReportGenerator {

    public static void generateReports(List<TestResultModel> results, String outputDir) {
        File dir = new File(outputDir);
        if (!dir.exists()) dir.mkdirs();

        generateExecutionReport(results, new File(dir, "execution-report.html"));
        generateDashboard(results, new File(dir, "dashboard.html"));
        generateTrends(results, new File(dir, "trends.html"));
    }

    private static void generateExecutionReport(List<TestResultModel> results, File outputFile) {
        long passed = results.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).count();
        long failed = results.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).count();
        long skipped = results.stream().filter(t -> "SKIPPED".equalsIgnoreCase(t.getStatus())).count();
        long total = results.size();
        double passPercentage = total > 0 ? ((double) passed / total) * 100.0 : 0.0;
        String dateStr = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());

        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n")
            .append("<meta charset=\"UTF-8\">\n")
            .append("<title>Enterprise E2E Test Execution Report</title>\n")
            .append("<style>\n")
            .append("body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; background: #0f172a; color: #f8fafc; }\n")
            .append(".header { background: linear-gradient(135deg, #1e293b, #0f172a); padding: 30px; border-bottom: 2px solid #334155; text-align: center; }\n")
            .append(".container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }\n")
            .append(".cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }\n")
            .append(".card { background: #1e293b; padding: 20px; border-radius: 12px; text-align: center; border: 1px solid #334155; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }\n")
            .append(".card h3 { margin: 0 0 10px; color: #94a3b8; font-size: 0.9rem; text-transform: uppercase; }\n")
            .append(".card .val { font-size: 2.2rem; font-weight: bold; }\n")
            .append(".val.pass { color: #10b981; } .val.fail { color: #ef4444; } .val.skip { color: #f59e0b; }\n")
            .append("table { width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 12px; overflow: hidden; border: 1px solid #334155; }\n")
            .append("th, td { padding: 14px 18px; text-align: left; border-bottom: 1px solid #334155; }\n")
            .append("th { background: #0f172a; color: #94a3b8; font-weight: 600; text-transform: uppercase; font-size: 0.8rem; }\n")
            .append(".badge { padding: 4px 12px; border-radius: 9999px; font-weight: 600; font-size: 0.75rem; text-transform: uppercase; }\n")
            .append(".badge.PASSED { background: rgba(16, 185, 129, 0.2); color: #10b981; }\n")
            .append(".badge.FAILED { background: rgba(239, 68, 68, 0.2); color: #ef4444; }\n")
            .append(".badge.SKIPPED { background: rgba(245, 158, 11, 0.2); color: #f59e0b; }\n")
            .append("</style>\n</head>\n<body>\n")
            .append("<div class=\"header\"><h1>Android Appium E2E Automation Report</h1><p>Execution Timestamp: ").append(dateStr).append("</p></div>\n")
            .append("<div class=\"container\">\n")
            .append("<div class=\"cards\">\n")
            .append("<div class=\"card\"><h3>Total Executed</h3><div class=\"val\">").append(total).append("</div></div>\n")
            .append("<div class=\"card\"><h3>Passed</h3><div class=\"val pass\">").append(passed).append("</div></div>\n")
            .append("<div class=\"card\"><h3>Failed</h3><div class=\"val fail\">").append(failed).append("</div></div>\n")
            .append("<div class=\"card\"><h3>Skipped</h3><div class=\"val skip\">").append(skipped).append("</div></div>\n")
            .append("<div class=\"card\"><h3>Pass Rate</h3><div class=\"val pass\">").append(String.format("%.2f%%", passPercentage)).append("</div></div>\n")
            .append("</div>\n")
            .append("<h2>Test Execution Results</h2>\n")
            .append("<table>\n<thead><tr><th>Test ID</th><th>Module</th><th>Test Name</th><th>Priority</th><th>Status</th><th>Duration</th></tr></thead>\n<tbody>\n");

        for (TestResultModel r : results) {
            html.append("<tr>")
                .append("<td>").append(r.getTestId()).append("</td>")
                .append("<td>").append(r.getModule()).append("</td>")
                .append("<td>").append(r.getTestName()).append("</td>")
                .append("<td>").append(r.getPriority()).append("</td>")
                .append("<td><span class=\"badge ").append(r.getStatus()).append("\">").append(r.getStatus()).append("</span></td>")
                .append("<td>").append(String.format("%.2fs", r.getExecutionTimeSeconds())).append("</td>")
                .append("</tr>\n");
        }

        html.append("</tbody>\n</table>\n</div>\n</body>\n</html>");

        try (PrintWriter writer = new PrintWriter(new FileWriter(outputFile))) {
            writer.write(html.toString());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void generateDashboard(List<TestResultModel> results, File outputFile) {
        generateExecutionReport(results, outputFile);
    }

    private static void generateTrends(List<TestResultModel> results, File outputFile) {
        generateExecutionReport(results, outputFile);
    }
}
