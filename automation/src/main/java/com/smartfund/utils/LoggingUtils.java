package com.smartfund.utils;

import com.smartfund.config.ConfigReader;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Date;

public class LoggingUtils {
    private static final String logDir = ConfigReader.getProperty("logs.dir").isEmpty() ? "target/TestResults/Logs/" : ConfigReader.getProperty("logs.dir");

    public static void log(String level, String message) {
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(new Date());
        String logEntry = String.format("[%s] [%s] %s", timestamp, level, message);
        System.out.println(logEntry);

        try {
            File dir = new File(logDir);
            if (!dir.exists()) dir.mkdirs();

            File logFile = new File(dir, "execution.log");
            try (PrintWriter out = new PrintWriter(new FileWriter(logFile, true))) {
                out.println(logEntry);
            }
        } catch (Exception ignored) {}
    }

    public static void info(String message) { log("INFO", message); }
    public static void error(String message) { log("ERROR", message); }
    public static void warn(String message) { log("WARN", message); }
}
