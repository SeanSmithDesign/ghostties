# Ghostties

**A multi-agent workspace terminal — built on [Ghostty](https://github.com/ghostty-org/ghostty)**

> **Work in Progress** — This project is in active early development.

## What is Ghostties?

Ghostties is a fork of [Ghostty](https://github.com/ghostty-org/ghostty), the fast, native, feature-rich terminal emulator. The goal is to add native workspace management for running multiple AI agents side-by-side — giving you a single terminal experience for multi-agent workflows.

For core terminal emulator documentation, downloads, and configuration, see the [upstream Ghostty repo](https://github.com/ghostty-org/ghostty) and [ghostty.org](https://ghostty.org/docs).

## First Launch

On first launch, macOS will prompt for access to folders like Desktop, Documents, and iCloud Drive. This is standard macOS behavior for any new terminal app — the prompts are triggered by commands running inside the terminal, not by Ghostties itself. You can safely deny access to any folder you don't need. To suppress all prompts, grant Full Disk Access in System Settings > Privacy & Security.

## Development

To get started building from source, see:

- [Developing Ghostty](HACKING.md) — build instructions, logging, linting
- [Contributing](CONTRIBUTING.md) — contribution guidelines

## Acknowledgments

Ghostties is built on [Ghostty](https://github.com/ghostty-org/ghostty), created by [Mitchell Hashimoto](https://github.com/mitchellh) and the Ghostty contributors. Ghostty is a fast, native, feature-rich terminal emulator — and the foundation that makes this project possible. Thank you to the entire Ghostty community.

## License

This project is licensed under the [MIT License](LICENSE), the same license as upstream Ghostty. Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors.
