package com.skillmap;

import com.skillmap.service.JobService;
import com.skillmap.service.ResumeService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

// Loads the full Spring context — tests real wiring
@SpringBootTest
@ActiveProfiles("test")  // uses application-test.properties
class SkillmapApplicationTests {

    @Autowired
    private JobService jobService;

    @Autowired
    private ResumeService resumeService;

    // Test 1 — Spring context loads without errors
    @Test
    void contextLoads() {
        // If this passes, your entire Spring wiring is correct
        // Beans are found, dependencies injected, config loaded
    }

    // Test 2 — Services are properly injected
    @Test
    void servicesAreInjected() {
        assert jobService != null : "JobService should be injected";
        assert resumeService != null : "ResumeService should be injected";
    }
}