package com.workshop.devopsdemo;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class SubmissionService {

    private static final Logger log = LoggerFactory.getLogger(SubmissionService.class);

    private final List<Submission> submissions = new CopyOnWriteArrayList<>();
    private final AtomicLong sequence = new AtomicLong();
    private final Counter submissionCounter;

    public SubmissionService(MeterRegistry meterRegistry) {
        this.submissionCounter = Counter.builder("app_submissions_total")
                .description("Total number of feedback submissions received")
                .register(meterRegistry);
        meterRegistry.gauge("app_submissions_current", submissions, List::size);
    }

    public Submission add(String name, String message) {
        Submission submission = new Submission(sequence.incrementAndGet(), name, message, Instant.now());
        submissions.add(submission);
        submissionCounter.increment();
        log.info("Submission #{} received from '{}'", submission.id(), name);
        return submission;
    }

    public List<Submission> findAll() {
        return submissions.reversed();
    }
}
