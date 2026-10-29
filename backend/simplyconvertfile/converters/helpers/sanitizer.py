#!/usr/bin/python3
"""
Command sanitizer for dangerous command detection.

This module provides security checking for commands before execution,
detecting potentially dangerous operations like file deletion, privilege
escalation, network access, and system control commands.
"""

import re
from pathlib import PurePosixPath
from typing import List, Optional, Union

from simplyconvertfile.utils.logging import logger
from simplyconvertfile.utils.text import text

from .commands import CommandParser
from .constants import DANGEROUS_COMMAND_CATEGORIES, DANGEROUS_COMMANDS


class CommandSanitizer:
    """Detects dangerous commands before execution.

    Scans command strings for potentially dangerous executables by splitting
    on shell operators and extracting the first token (executable name) from
    each sub-command. Used as a security gate at the command execution
    chokepoint.

    Examples:
        >>> sanitizer = CommandSanitizer()
        >>> reason = sanitizer.check_command("ffmpeg -i input.mp4 output.mp3")
        >>> print(reason)
        None
        >>> reason = sanitizer.check_command("rm -rf /tmp/test && ffmpeg ...")
        >>> print(reason)
        Blocked command 'rm' detected (file deletion)
    """

    # Pattern to split commands on shell operators (&&, ||, |, ;)
    # while preserving the ability to identify each sub-command.
    _SPLIT_PATTERN = re.compile(r"\s*(?:&&|\|\||\||;)\s*")

    def __init__(self) -> None:
        """Initialize the command sanitizer."""

    def check_command(self, command: Union[str, List[str]]) -> Optional[str]:
        """Check a command for dangerous executables.

        Parses the command string (handling shell operators), extracts the
        executable name from each sub-command, and checks against the
        dangerous commands set.

        Args:
            command: Command to check, either as a string or list of strings.

        Returns:
            Optional[str]: Human-readable reason string if a dangerous command
                          is detected (e.g., "Blocked command 'rm' detected
                          (file deletion)"), or None if the command is safe.

        Examples:
            >>> sanitizer = CommandSanitizer()
            >>> sanitizer.check_command("convert input.jpg output.png")
            >>> sanitizer.check_command("sudo ffmpeg -i input.mp4 output.mp3")
            "Blocked command 'sudo' detected (privilege escalation)"
        """
        if isinstance(command, list):
            if not command:
                return None
            # For list-form commands, check if it's a shell command
            # (tool, full_cmd_str) pair or a regular direct-execution argument list
            if (
                len(command) == 2
                and isinstance(command[1], str)
                and CommandParser.is_shell_command(command[1])
            ):
                return self._check_command_string(command[1])

            return self._check_executable_name(
                str(command[0]), " ".join(str(c) for c in command)
            )

        return self._check_command_string(str(command))

    def _check_executable_name(
        self, executable: str, full_command_context: str
    ) -> Optional[str]:
        """Check whether a single executable name is in the dangerous commands set."""
        if not executable:
            return None
        base_name = PurePosixPath(executable).name
        if base_name in DANGEROUS_COMMANDS:
            category = DANGEROUS_COMMAND_CATEGORIES.get(
                base_name, text.Security.CATEGORY_DANGEROUS_OPERATION
            )
            reason = f"Blocked command '{base_name}' detected ({category})"
            logger.warning(
                "Dangerous command detected: '{}' in command: {}",
                base_name,
                full_command_context[:100],
            )
            return reason
        return None

    def _check_command_string(self, command_str: str) -> Optional[str]:
        """Check a command string for dangerous executables.

        Splits the command on unquoted shell operators and checks each
        sub-command's executable against the dangerous commands set.

        Args:
            command_str: Raw command string to analyze.

        Returns:
            Optional[str]: Reason string if dangerous, None if safe.
        """
        if not command_str or not command_str.strip():
            return None

        # Split on unquoted shell operators to get individual sub-commands
        sub_commands = CommandParser.split_unquoted(
            command_str, ("&&", "||", "|", ";")
        )

        for sub_cmd in sub_commands:
            sub_cmd = sub_cmd.strip()
            if not sub_cmd:
                continue

            executable = self._extract_executable(sub_cmd)
            if not executable:
                continue

            reason = self._check_executable_name(executable, command_str)
            if reason:
                return reason

        return None

    @staticmethod
    def _extract_executable(sub_command: str) -> Optional[str]:
        """Extract the executable name from a sub-command string.

        Handles common patterns like environment variable assignments
        before the executable (e.g., "FOO=bar command args").

        Args:
            sub_command: A single sub-command string (no shell operators).

        Returns:
            Optional[str]: The executable name, or None if not parseable.
        """
        tokens = sub_command.split()
        for token in tokens:
            # Skip environment variable assignments (KEY=value)
            if "=" in token and not token.startswith("-"):
                continue
            return token
        return None
