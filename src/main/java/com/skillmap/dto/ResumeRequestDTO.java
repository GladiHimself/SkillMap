package com.skillmap.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ResumeRequestDTO {

    @NotBlank(message = "Candidate name is required")
    private String candidateName;

    @NotBlank(message = "Email is required")
    @Email(message = "Please provide a valid email address")
    private String email;

}
