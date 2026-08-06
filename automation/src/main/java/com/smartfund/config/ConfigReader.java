package com.smartfund.config;

import java.io.InputStream;
import java.util.Properties;

public class ConfigReader {
    private static final Properties properties = new Properties();

    static {
        try (InputStream input = ConfigReader.class.getClassLoader().getResourceAsStream("config.properties")) {
            if (input != null) {
                properties.load(input);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static String getProperty(String key) {
        return System.getProperty(key, properties.getProperty(key, ""));
    }

    public static int getIntProperty(String key, int defaultValue) {
        String val = getProperty(key);
        try {
            return Integer.parseInt(val);
        } catch (Exception e) {
            return defaultValue;
        }
    }
}
