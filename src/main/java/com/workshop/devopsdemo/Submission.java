package com.workshop.devopsdemo;

import java.time.Instant;

public record Submission(long id, String name, String message, Instant submittedAt) {
}
