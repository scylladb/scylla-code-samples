package com.scylladb.data;

import au.com.bytecode.opencsv.CSVReader;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;

import java.io.FileReader;
import java.io.IOException;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

// Our parser class.
public class SP_DataParser {
    // Reader, to keep open.
    CSVReader reader;
    // Store the header of csv file.
    private String[] header;

    /**
     * @param filePath: data file path.
     * @throws IOException
     */
    public SP_DataParser(String filePath) throws IOException {
        reader = new CSVReader(new FileReader(filePath));
        header = reader.readNext();
    }

    /**
     * Given a json string, return a Map representation of it.
     *
     * @param json
     * @return
     */
    public static Map<String, String> decode(String json) {
        Gson gson = new GsonBuilder().create();
        Type typeOfHashMap = new TypeToken<Map<String, String>>() {
        }.getType();
        return gson.fromJson(json, typeOfHashMap);
    }

    /**
     * Given a map object, return a json string.
     *
     * @param map
     * @return
     */
    private String encode(Map<String, String> map) {
        Gson gson = new GsonBuilder().create();
        return gson.toJson(map);
    }

    /**
     * Parse a csv line to a json string, using the headers read in the constructor.
     *
     * @param line
     * @return
     */
    private String json(String[] line) {
        Map<String, String> m = new HashMap<>();
        for (int i = 0; i < header.length; i++) {
            m.put(header[i], line[i]);
        }
        return encode(m);
    }

    /**
     * Given a json string, return the value of `key`.
     *
     * @param json
     * @param key
     * @return
     */
    public String getKey(String json, String key) {
        return decode(json).get(key);
    }

    public ArrayList<String> read(int n) throws IOException {
        ArrayList<String> linesJson = new ArrayList<>();
        int i = 0;
        String[] nextLine;
        while (i < n && (nextLine = reader.readNext()) != null) {
            linesJson.add(json(nextLine));
            i++;
        }
        return linesJson;
    }

    /**
     * Close our reader.
     *
     * @throws IOException
     */
    public void close() throws IOException {
        reader.close();
    }
}
