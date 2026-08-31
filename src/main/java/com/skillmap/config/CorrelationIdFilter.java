package com.skillmap.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

// Runs first, before any controller logic
// Attaches a correlation ID to every request so we can trace
// a single request across all log lines it produces
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter extends OncePerRequestFilter {

    private static final String CORRELATION_ID_HEADER = "X-Correlation-Id";
    private static final String MDC_KEY = "correlationId";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain)
            throws ServletException, IOException {

        // If the client already sent a correlation ID (e.g. from Lambda
        // or another service), reuse it. Otherwise generate a new one.
        String correlationId = request.getHeader(CORRELATION_ID_HEADER);
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = "req-" + UUID.randomUUID().toString().substring(0, 8);
        }

        // MDC puts this value into thread-local storage
        // Every log statement on this thread automatically includes it
        MDC.put(MDC_KEY, correlationId);

        // Echo it back in the response so the client can log it too
        response.setHeader(CORRELATION_ID_HEADER, correlationId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            // Critical — clear MDC after the request completes
            // Otherwise thread pool reuse leaks correlation IDs
            // between unrelated requests
            MDC.clear();
        }
    }
}