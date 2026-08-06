package com.smartfund.utils;

import com.smartfund.models.TestResultModel;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;

public class MarkdownReportGenerator {

    public static void generateSummary(List<TestResultModel> results, String outputDir) {
        File dir = new File(outputDir);
        if (!dir.exists()) dir.mkdirs();

        long passed = results.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).count();
        long failed = results.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).count();
        long skipped = results.stream().filter(t -> "SKIPPED".equalsIgnoreCase(t.getStatus())).count();
        long total = results.size();
        double passPercentage = total > 0 ? ((double) passed / total) * 100.0 : 0.0;
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());

        StringBuilder md = new StringBuilder();
        md.append("# Android Appium E2E Execution Summary\n\n")
          .append("**Execution Date:** ").append(timestamp).append("\n")
          .append("**APK Version:** 1.0.0+1\n")
          .append("**Device:** Android Emulator\n")
          .append("**Android Version:** 13.0 (API 33)\n\n")
          .append("### Execution Metrics\n\n")
          .append("- **Total Test Cases:** ").append(total).append("\n")
          .append("- **Executed:** ").append(total).append("\n")
          .append("- **Passed:** ").append(passed).append("\n")
          .append("- **Failed:** ").append(failed).append("\n")
          .append("- **Skipped:** ").append(skipped).append("\n")
          .append("- **Pass Percentage:** ").append(String.format("%.2f%%", passPercentage)).append("\n\n")
          .append("### Sample Passing Executed Test Cases\n\n");

        int count = 0;
        for (TestResultModel t : results) {
            if ("PASSED".equalsIgnoreCase(t.getStatus()) && count < 10) {
                md.append("✓ ").append(t.getTestId()).append(" - ").append(t.getTestName()).append("\n");
                count++;
            }
        }

        if (failed > 0) {
            md.append("\n### Failed Tests\n\n");
            for (TestResultModel t : results) {
                if ("FAILED".equalsIgnoreCase(t.getStatus())) {
                    md.append("✗ ").append(t.getTestId()).append(" - ").append(t.getTestName()).append("\n")
                      .append("   Reason: ").append(t.getFailureReason()).append("\n");
                }
            }
        }

        try (PrintWriter writer = new PrintWriter(new FileWriter(new File(dir, "summary.md")))) {
            writer.write(md.toString());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
