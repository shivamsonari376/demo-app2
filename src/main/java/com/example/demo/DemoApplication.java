
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}

/**
 * Simple REST controller to test the app.
 * - GET /       -> "Hello from Spring Boot on Java 21!"
 * - GET /health -> "OK"
 */
@RestController
class HelloController {

    @GetMapping("/")
    public String hello() {
        return "Hello from Spring Boot on Java 21! This is created By SHIVAM SINGH & SUJIT DUTTA";
    }

    // Optional: a tiny health endpoint useful for readiness checks
    @GetMapping("/health")
    public String health() {
        return "OK";
    }
}

