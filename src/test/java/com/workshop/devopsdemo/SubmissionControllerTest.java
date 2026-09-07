package com.workshop.devopsdemo;

import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SubmissionController.class)
class SubmissionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private SubmissionService submissionService;

    @Test
    void indexShowsForm() throws Exception {
        when(submissionService.findAll()).thenReturn(List.of());

        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Feedback Form")));
    }

    @Test
    void submitWithValidDataAddsSubmissionAndShowsItInTable() throws Exception {
        Submission saved = new Submission(1L, "Alice", "Hello there", Instant.now());
        when(submissionService.add(anyString(), anyString())).thenReturn(saved);
        when(submissionService.findAll()).thenReturn(List.of(saved));

        mockMvc.perform(post("/submissions").param("name", "Alice").param("message", "Hello there"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Alice")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Hello there")));
    }

    @Test
    void submitWithBlankNameShowsValidationError() throws Exception {
        when(submissionService.findAll()).thenReturn(List.of());

        mockMvc.perform(post("/submissions").param("name", "").param("message", "Hello there"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Name is required")));
    }

    @Test
    void submitStripsNewlinesFromLoggedNameToPreventLogInjection() throws Exception {
        Submission saved = new Submission(1L, "Alice", "Hello there", Instant.now());
        when(submissionService.add(anyString(), anyString())).thenReturn(saved);
        when(submissionService.findAll()).thenReturn(List.of(saved));

        var logger = (ch.qos.logback.classic.Logger) LoggerFactory.getLogger(SubmissionController.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);

        try {
            mockMvc.perform(post("/submissions")
                            .param("name", "Alice\nFAKE LOG LINE: admin login succeeded\r\n")
                            .param("message", "Hello there"))
                    .andExpect(status().isOk());
        } finally {
            logger.detachAppender(appender);
        }

        String formattedMessage = appender.list.get(0).getFormattedMessage();
        assertThat(formattedMessage).doesNotContain("\n").doesNotContain("\r");
    }
}
