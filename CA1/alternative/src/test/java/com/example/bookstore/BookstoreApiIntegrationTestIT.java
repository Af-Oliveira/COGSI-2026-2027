package com.example.bookstore;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.web.servlet.client.RestTestClient;

/**
 * Integration tests that boot the full Spring application context on a random
 * port and exercise the public REST API over HTTP.
 *
 * Spring Boot 4 removed {@code TestRestTemplate}; the modern replacement is
 * {@link RestTestClient}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BookstoreApiIntegrationTestIT {

    @LocalServerPort
    private int port;

    private RestTestClient client;

    @BeforeEach
    void setUp() {
        client = RestTestClient.bindToServer()
                .baseUrl("http://localhost:" + port)
                .build();
    }

    @Test
    void booksEndpointReturnsSeededData() {
        String body = client.get().uri("/books")
                .exchange()
                .expectStatus().isOk()
                .returnResult(String.class)
                .getResponseBody();

        assertThat(body).contains("Clean Code");
        assertThat(body).contains("Effective Java");
    }

    @Test
    void healthEndpointReportsUp() {
        String body = client.get().uri("/actuator/health")
                .exchange()
                .expectStatus().isOk()
                .returnResult(String.class)
                .getResponseBody();

        assertThat(body).contains("UP");
    }
}
