/*
 * Unit tests for the Gradle demo chat application.
 */

package org.example;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * A simple unit test suite that exercises the pure logic of the application
 * without opening sockets or graphical user interfaces.
 */
class AppTest {

    /**
     * The greeting is expected to advertise the name of the chat application.
     */
    @Test
    @DisplayName("greeting mentions the multi-user chat application")
    void greetingMentionsApplicationName() {
        String greeting = new App().getGreeting();

        assertNotNull(greeting, "The greeting must not be null");
        assertTrue(greeting.contains("Multi-User Chat Application"),
                "The greeting should contain the application name");
    }

    /**
     * The chat server must be constructible with a port and hold no connections yet.
     */
    @Test
    @DisplayName("chat server can be instantiated with a port")
    void chatServerCanBeInstantiated() {
        ChatServer server = new ChatServer(59001);

        assertNotNull(server, "The chat server instance must not be null");
    }
}
