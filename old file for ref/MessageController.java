package com.tsacademy.app;

import java.net.InetAddress;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
public class MessageController {

    private final JdbcTemplate jdbc;

    public MessageController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, Object> health() throws Exception {
        Integer one = jdbc.queryForObject("SELECT 1", Integer.class);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("status", "UP");
        result.put("database", one != null && one == 1 ? "connected" : "unknown");
        result.put("pod", InetAddress.getLocalHost().getHostName());
        return result;
    }

    @GetMapping("/messages")
    public List<Map<String, Object>> list() {
        return jdbc.queryForList("SELECT id, content, created_at FROM messages ORDER BY id DESC LIMIT 50");
    }

    @PostMapping("/messages")
    public Map<String, Object> add(@RequestBody Map<String, String> body) {
        String content = body.get("content");
        if (content == null || content.isBlank() || content.length() > 255) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "content must be 1-255 characters");
        }
        jdbc.update("INSERT INTO messages (content) VALUES (?)", content.trim());
        return Map.of("saved", true);
    }
}
