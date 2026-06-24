package com.skillmap.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class JobRequestDTO {

    @NotBlank(message = "Job title is required")
    private String title;

    @NotBlank(message = "Company name is required")
    private String company;

    @NotBlank(message = "Required skills cannot be empty")
    private String requiredSkills;

    private String description;
}
