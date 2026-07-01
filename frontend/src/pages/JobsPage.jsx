import { useState, useEffect } from 'react';
import { getAllJobs, createJob } from '../api';

export default function JobsPage() {
  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errors, setErrors] = useState({});
  const [success, setSuccess] = useState('');

  // Form state
  const [form, setForm] = useState({
    title: '',
    company: '',
    requiredSkills: '',
    description: ''
  });

  // Load jobs on mount
  useEffect(() => {
    fetchJobs();
  }, []);

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
    try {
      const newJob = await createJob(form);
      setJobs([...jobs, newJob]);   // add to list without refetching
      setForm({ title: '', company: '', requiredSkills: '', description: '' });
      setSuccess('Job created successfully!');
    } catch (err) {
      setErrors(err);  // validation errors from backend
    }
  };

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  return (
    <div className="container">
      <h2 style={{ margin: '1.5rem 0 1rem' }}>Job Postings</h2>

      {/* Create Job Form */}
      <div className="card">
        <h3 style={{ marginBottom: '1rem' }}>Post a New Job</h3>

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
          {errors.company && <div className="error">{errors.company}</div>}
        </div>

        <div className="form-group">
          <label>Required Skills (comma separated)</label>
          <input
            name="requiredSkills"
            value={form.requiredSkills}
            onChange={handleChange}
            placeholder="e.g. Java, Spring Boot, AWS"
          />
          {errors.requiredSkills && <div className="error">{errors.requiredSkills}</div>}
        </div>

        <div className="form-group">
          <label>Description</label>
          <textarea
            name="description"
            value={form.description}
            onChange={handleChange}
            rows={3}
            placeholder="Brief role description"
          />
        </div>

        {success && <div className="success">{success}</div>}

        <button className="btn btn-primary" onClick={handleSubmit}>
          Post Job
        </button>
      </div>

      {/* Jobs List */}
      {loading ? (
        <p>Loading jobs...</p>
      ) : jobs.length === 0 ? (
        <p>No jobs posted yet.</p>
      ) : (
        jobs.map(job => (
          <div className="card" key={job.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <h3>{job.title}</h3>
                <p style={{ color: '#64748b', margin: '0.3rem 0' }}>{job.company}</p>
                <p style={{ fontSize: '0.9rem' }}>{job.description}</p>
                <div style={{ marginTop: '0.5rem' }}>
                  {job.requiredSkills.split(',').map(skill => (
                    <span key={skill} className="badge badge-blue" style={{ marginRight: '0.3rem' }}>
                      {skill.trim()}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>
        ))
      )}
    </div>
  );
}