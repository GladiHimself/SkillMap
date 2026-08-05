package com.skillmap.service;

import com.skillmap.dto.MatchResultDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final SnsClient snsClient;

    // Reads SNS_TOPIC_ARN from properties
    // Empty string if not configured — skips notification gracefully
    @Value("${aws.sns.topic.arn:}")
    private String snsTopicArn;

    public void sendMatchNotification(MatchResultDTO result) {

        // Skip if SNS not configured — safe for local development
        if (snsTopicArn == null || snsTopicArn.isBlank()) {
            log.info("SNS topic ARN not configured — skipping notification");
            log.info("Match result: {} scored {}% for {} at {}",
                    result.getCandidateName(),
                    result.getMatchScore(),
                    result.getJobTitle(),
                    result.getCompany());
            return;
        }

        try {
            String subject = String.format(
                    "SkillMap — Your Match Score: %.1f%% for %s at %s",
                    result.getMatchScore(),
                    result.getJobTitle(),
                    result.getCompany()
            );

            String message = buildMatchMessage(result);

            snsClient.publish(PublishRequest.builder()
                    .topicArn(snsTopicArn)
                    .subject(subject)
                    .message(message)
                    .build());

            log.info("Match notification sent successfully for {}",
                    result.getCandidateName());

        } catch (Exception e) {
            // Never fail the main flow because of notification failure
            log.error("Failed to send SNS notification: {}", e.getMessage());
        }
    }

    private String buildMatchMessage(MatchResultDTO result) {
        // Build matched skills string
        String matchedSkills = result.getMatchedSkills().isEmpty()
                ? "None"
                : String.join(", ", result.getMatchedSkills());

        // Build missing skills string
        String missingSkills = result.getMissingSkills().isEmpty()
                ? "None — perfect match!"
                : String.join(", ", result.getMissingSkills());

        // Format the email body
        return String.format("""
                Hi %s,
                
                Your resume has been matched against a job on SkillMap!
                
                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                JOB DETAILS
                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                Position:  %s
                Company:   %s
                
                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                MATCH RESULTS
                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                Match Score:      %.1f%%
                Verdict:          %s
                
                ✅ Matched Skills: %s
                
                ❌ Missing Skills: %s
                
                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                
                %s
                
                Good luck with your application!
                
                — The SkillMap Team
                """,
                result.getCandidateName(),
                result.getJobTitle(),
                result.getCompany(),
                result.getMatchScore(),
                result.getVerdict(),
                matchedSkills,
                missingSkills,
                getMotivationalMessage(result.getMatchScore())
        );
    }

    private String getMotivationalMessage(double score) {
        if (score >= 80) return "🌟 Outstanding! You're a top candidate for this role.";
        if (score >= 60) return "👍 Great profile! Consider applying — you have strong overlap.";
        if (score >= 40) return "📚 Keep building your skills. Focus on the missing areas.";
        return "💪 Keep learning! Every skill you add improves your match score.";
    }
}