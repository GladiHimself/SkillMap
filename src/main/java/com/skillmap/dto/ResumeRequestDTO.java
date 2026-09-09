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

    // S3 object key — set by the frontend after getting a pre-signed URL
    // Lambda uses this to find and update the correct record
    private String s3Key;

}
