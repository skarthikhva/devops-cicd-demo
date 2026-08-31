package com.workshop.devopsdemo;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class SubmissionForm {

    @NotBlank(message = "Name is required")
    @Size(max = 100)
    private String name;

    @NotBlank(message = "Message is required")
    @Size(max = 500)
    private String message;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
