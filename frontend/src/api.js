// Central place for all API calls
// If backend URL changes, we only change it here

const BASE_URL = '/api/v1';

// ── Jobs ──────────────────────────────────────
export const getAllJobs = async () => {
  const res = await fetch(`${BASE_URL}/jobs`);
  if (!res.ok) throw new Error('Failed to fetch jobs');
  return res.json();
};

export const createJob = async (jobData) => {
  const res = await fetch(`${BASE_URL}/jobs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(jobData)
  });
  if (!res.ok) {
    const error = await res.json();
    throw error;  // validation errors from GlobalExceptionHandler
  }
  return res.json();
};

// ── Resumes ───────────────────────────────────
export const getAllResumes = async () => {
  const res = await fetch(`${BASE_URL}/resumes`);
  if (!res.ok) throw new Error('Failed to fetch resumes');
  return res.json();
};

export const createResume = async (resumeData) => {
  const res = await fetch(`${BASE_URL}/resumes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(resumeData)
  });
  if (!res.ok) {
    const error = await res.json();
    throw error;
  }
  return res.json();
};

export const matchResumeToJob = async (resumeId, jobId) => {
  const res = await fetch(
    `/api/v1/match?resumeId=${resumeId}&jobId=${jobId}`,
    { method: 'POST' }
  );
  if (!res.ok) throw new Error('Match failed');
  return res.json();
};