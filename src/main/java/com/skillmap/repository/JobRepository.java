package com.skillmap.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.skillmap.model.Job;

public interface JobRepository extends JpaRepository<Job, Long> {

}
