import { useState, useEffect } from 'react';
import { getAllJobs, getAllResumes, matchResumeToJob } from '../api';

export default function MatchPage() {
  const [jobs, setJobs] = useState([]);
  const [resumes, setResumes] = useState([]);
  const [selectedJob, setSelectedJob] = useState('');
  const [selectedResume, setSelectedResume] = useState('');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    getAllJobs().then(setJobs);
    getAllResumes().then(setResumes);
  }, []);

  const handleMatch = async () => {
    if (!selectedJob || !selectedResume) return;
    setLoading(true);
    setResult(null);
    try {
      const data = await matchResumeToJob(selectedResume, selectedJob);
      setResult(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const getScoreColor = (score) => {
    if (score >= 80) return '#16a34a';
    if (score >= 60) return '#ca8a04';
    if (score >= 40) return '#ea580c';
    return '#dc2626';
  };

  return (
    <div className="container">
      <h2 style={{ margin: '1.5rem 0 1rem' }}>Match Resume to Job</h2>

      <div className="card">
        <h3 style={{ marginBottom: '1rem' }}>Select Resume and Job</h3>

        <div className="form-group">
          <label>Select Resume</label>
          <select
            value={selectedResume}
            onChange={e => setSelectedResume(e.target.value)}
          >
            <option value="">Choose a candidate...</option>
            {resumes.map(r => (
              <option key={r.id} value={r.id}>
                {r.candidateName} — {r.status}
              </option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label>Select Job</label>
          <select
            value={selectedJob}
            onChange={e => setSelectedJob(e.target.value)}
          >
            <option value="">Choose a job...</option>
            {jobs.map(j => (
              <option key={j.id} value={j.id}>
                {j.title} at {j.company}
              </option>
            ))}
          </select>
        </div>

        <button
          className="btn btn-primary"
          onClick={handleMatch}
          disabled={loading || !selectedJob || !selectedResume}
        >
          {loading ? 'Calculating...' : 'Calculate Match Score'}
        </button>
      </div>

      {result && (
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>{result.candidateName}</h3>
              <p style={{ color: '#64748b' }}>
                {result.jobTitle} at {result.company}
              </p>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{
                fontSize: '2.5rem',
                fontWeight: '700',
                color: getScoreColor(result.matchScore)
              }}>
                {result.matchScore}%
              </div>
              <div style={{ fontSize: '0.8rem', color: '#64748b' }}>match score</div>
            </div>
          </div>

          <p style={{
            margin: '1rem 0',
            padding: '0.75rem',
            background: '#f8fafc',
            borderRadius: '6px',
            fontStyle: 'italic'
          }}>
            {result.verdict}
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <div>
              <h4 style={{ marginBottom: '0.5rem', color: '#16a34a' }}>
                ✅ Matched Skills ({result.matchedSkills.length})
              </h4>
              {result.matchedSkills.map(skill => (
                <span key={skill} className="badge badge-green"
                  style={{ marginRight: '0.3rem', marginBottom: '0.3rem', display: 'inline-block' }}>
                  {skill}
                </span>
              ))}
            </div>
            <div>
              <h4 style={{ marginBottom: '0.5rem', color: '#dc2626' }}>
                ❌ Missing Skills ({result.missingSkills.length})
              </h4>
              {result.missingSkills.map(skill => (
                <span key={skill} className="badge badge-red"
                  style={{ marginRight: '0.3rem', marginBottom: '0.3rem', display: 'inline-block' }}>
                  {skill}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}