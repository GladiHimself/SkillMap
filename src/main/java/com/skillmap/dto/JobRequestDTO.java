package com.skillmap.dto;

import lombok.Data;

@Data
public class JobRequestDTO {

    private String title;

    private String company;

    private String requiredSkills;

    private String description;
}
