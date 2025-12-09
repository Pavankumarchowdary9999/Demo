package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;

@SpringBootApplication
@RestController
public class DemoApplication {

    @GetMapping("/")
    public String home() {
        return "Hello from " + System.getenv().getOrDefault("HOSTNAME", "unknown");
    }

    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
