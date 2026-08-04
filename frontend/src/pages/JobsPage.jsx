import { useState, useEffect } from 'react';
import { getAllJobs, createJob } from '../api';

export default function JobsPage() {
  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState({});
  const [success, setSuccess] = useState('');
  const [parsing, setParsing] = useState(false);

  const [form, setForm] = useState({
    title: '',
    company: '',
    description: '',
    requiredSkills: ''
  });

  useEffect(() => { fetchJobs(); }, []);

  const fetchJobs = async () => {
    try {
      const data = await getAllJobs();
      setJobs(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    setErrors({});
    setSuccess('');
    setParsing(true);
    try {
      const newJob = await createJob(form);
      setJobs([...jobs, newJob]);
      setForm({ title: '', company: '', description: '', requiredSkills: '' });
      setSuccess('Job posted! AI extracted skills automatically.');
    } catch (err) {
      setErrors(err);
    } finally {
      setParsing(false);
    }
  };

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  return (
    <div className="container">
      <h2 style={{ margin: '1.5rem 0 1rem' }}>Job Postings</h2>

      <div className="card">
        <h3 style={{ marginBottom: '0.5rem' }}>Post a New Job</h3>
        <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '1rem' }}>
          Paste the full job description — AI will extract required skills automatically.
        </p>

        <div className="form-group">
          <label>Job Title</label>
          <input
            name="title"
            value={form.title}
            onChange={handleChange}
            placeholder="e.g. Backend Developer"
          />
          {errors.title && <div className="error">{errors.title}</div>}
        </div>

        <div className="form-group">
          <label>Company</label>
          <input
            name="company"
            value={form.company}
            onChange={handleChange}
            placeholder="e.g. Stripe"
          />
        </div>

        <div className="form-group">
          <label>Job Description</label>
          <textarea
            name="description"
            value={form.description}
            onChange={handleChange}
            rows={6}
            placeholder="Paste the full job description here. AI will automatically extract the required technical skills..."
          />
          <small style={{ color: '#64748b' }}>
            AI will extract skills from this description automatically
          </small>
        </div>

        <div className="form-group">
          <label>Required Skills (optional — leave blank to let AI extract)</label>
          <input
            name="requiredSkills"
            value={form.requiredSkills}
            onChange={handleChange}
            placeholder="e.g. Java, Spring Boot, AWS (or leave blank)"
          />
        </div>

        {success && <div className="success">{success}</div>}

        <button
          className="btn btn-primary"
          onClick={handleSubmit}
          disabled={parsing}
        >
          {parsing ? 'AI is extracting skills...' : 'Post Job'}
        </button>
      </div>

      {loading ? (
        <p>Loading jobs...</p>
      ) : jobs.length === 0 ? (
        <p>No jobs posted yet.</p>
      ) : (
        jobs.map(job => (
          <div className="card" key={job.id}>
            <h3>{job.title}</h3>
            <p style={{ color: '#64748b', margin: '0.3rem 0' }}>{job.company}</p>
            <p style={{ fontSize: '0.9rem', margin: '0.3rem 0' }}>{job.description}</p>
            {job.requiredSkills && (
              <div style={{ marginTop: '0.5rem' }}>
                {job.requiredSkills.split(',').map(skill => (
                  <span key={skill} className="badge badge-blue"
                    style={{ marginRight: '0.3rem' }}>
                    {skill.trim()}
                  </span>
                ))}
              </div>
            )}
          </div>
        ))
      )}
    </div>
  );
}