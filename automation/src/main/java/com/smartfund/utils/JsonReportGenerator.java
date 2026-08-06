package com.smartfund.utils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.smartfund.models.TestResultModel;

import java.io.File;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class JsonReportGenerator {

    public static void generateReport(List<TestResultModel> results, String outputDir) {
        File dir = new File(outputDir);
        if (!dir.exists()) dir.mkdirs();

        long passed = results.stream().filter(t -> "PASSED".equalsIgnoreCase(t.getStatus())).count();
        long failed = results.stream().filter(t -> "FAILED".equalsIgnoreCase(t.getStatus())).count();
        long skipped = results.stream().filter(t -> "SKIPPED".equalsIgnoreCase(t.getStatus())).count();
        long total = results.size();
        double passPercentage = total > 0 ? ((double) passed / total) * 100.0 : 0.0;

        Map<String, Object> summaryMap = new HashMap<>();
        summaryMap.put("totalTests", total);
        summaryMap.put("passed", passed);
        summaryMap.put("failed", failed);
        summaryMap.put("skipped", skipped);
        summaryMap.put("passPercentage", passPercentage);
        summaryMap.put("testResults", results);

        try {
            ObjectMapper mapper = new ObjectMapper();
            mapper.enable(SerializationFeature.INDENT_OUTPUT);
            mapper.writeValue(new File(dir, "execution-results.json"), summaryMap);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
