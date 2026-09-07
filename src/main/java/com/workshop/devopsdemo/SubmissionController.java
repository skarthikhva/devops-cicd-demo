package com.workshop.devopsdemo;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.validation.BindingResult;

@Controller
public class SubmissionController {

    private static final Logger log = LoggerFactory.getLogger(SubmissionController.class);

    private final SubmissionService submissionService;

    public SubmissionController(SubmissionService submissionService) {
        this.submissionService = submissionService;
    }

    @GetMapping("/")
    public String index(Model model) {
        if (!model.containsAttribute("submissionForm")) {
            model.addAttribute("submissionForm", new SubmissionForm());
        }
        model.addAttribute("submissions", submissionService.findAll());
        return "index";
    }

    @PostMapping("/submissions")
    public String submit(@Valid @ModelAttribute("submissionForm") SubmissionForm form,
                          BindingResult bindingResult,
                          Model model) {
        if (bindingResult.hasErrors()) {
            model.addAttribute("submissions", submissionService.findAll());
            return "index";
        }
        log.info("New submission from {}", sanitizeForLog(form.getName()));
        submissionService.add(form.getName(), form.getMessage());
        model.addAttribute("submissionForm", new SubmissionForm());
        model.addAttribute("submissions", submissionService.findAll());
        return "index";
    }

    // Strips CR/LF so user input can't forge extra log lines (log injection, CWE-117).
    private static String sanitizeForLog(String value) {
        return value.replaceAll("[\r\n]", "_");
    }
}
