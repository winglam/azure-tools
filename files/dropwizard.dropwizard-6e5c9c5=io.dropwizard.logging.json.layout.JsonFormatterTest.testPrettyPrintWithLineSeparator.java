package io.dropwizard.logging.json.layout;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import io.dropwizard.jackson.Jackson;
import org.junit.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

public class JsonFormatterTest {

    private final Map<String, Object> map = ImmutableMap.of("name", "Jim", "hobbies",
        ImmutableList.of("Reading", "Biking", "Snorkeling"));
    private final ObjectMapper objectMapper = Jackson.newObjectMapper();

    @Test
    public void testPrettyPrintWithLineSeparator() {
        JsonFormatter formatter = new JsonFormatter(objectMapper, true, true);
        assertThat(formatter.toJson(map)).isEqualTo(String.format("{%n" +
                "  \"name\" : \"Jim\",%n" +
                "  \"hobbies\" : [ \"Reading\", \"Biking\", \"Snorkeling\" ]%n" +
                "}%n"));
    }
}
