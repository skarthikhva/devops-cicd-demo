package com.workshop.devopsdemo;

import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;

import static org.assertj.core.api.Assertions.assertThat;

class SubmissionServiceTest {

    private SubmissionService service;
    private MeterRegistry meterRegistry;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        service = new SubmissionService(meterRegistry);
    }

    @Test
    void addStoresSubmissionAndAssignsIncrementingIds() {
        Submission first = service.add("Alice", "Hello");
        Submission second = service.add("Bob", "World");

        assertThat(first.id()).isEqualTo(1L);
        assertThat(second.id()).isEqualTo(2L);
        assertThat(service.findAll()).hasSize(2);
    }

    @Test
    void findAllReturnsMostRecentFirst() {
        service.add("Alice", "First");
        service.add("Bob", "Second");

        assertThat(service.findAll()).extracting(Submission::name).containsExactly("Bob", "Alice");
    }

    @Test
    void addIncrementsSubmissionCounterMetric() {
        service.add("Alice", "Hello");
        service.add("Bob", "World");

        double count = meterRegistry.get("app_submissions_total").counter().count();
        assertThat(count).isEqualTo(2.0);
    }

    @Test
    void addStripsNewlinesFromLoggedNameToPreventLogInjection() {
        var logger = (ch.qos.logback.classic.Logger) LoggerFactory.getLogger(SubmissionService.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);

        try {
            service.add("Alice\nFAKE LOG LINE: admin login succeeded\r\n", "Hello");
        } finally {
            logger.detachAppender(appender);
        }

        String formattedMessage = appender.list.get(0).getFormattedMessage();
        assertThat(formattedMessage).doesNotContain("\n").doesNotContain("\r");
    }
}
