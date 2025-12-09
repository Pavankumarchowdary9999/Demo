package com.example.demo;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class DemoApplicationTests {
    @Test
    void simpleTest() {
        assertThat(1 + 1).isEqualTo(2);
    }
}
