
# KeyVox Contribution Guide

The guidelines below document the process for contributing to the KeyVox repository. Please read the whole thing.

## Goals

First and foremost, this is a community driven project and I want it to remain that way. That means contributions aren't just limited to code. The design philosophy is listed in the [engineering notes](Docs/ENGINEERING.md), but outside of that, I truly appreciate any contributions in the form of:

- Improving docs.
- Reviewing pull requests.
- Expanding language support and test coverage.
- Fixing typos.
- Lexicon and common words updates.
- Anything that can make a meaningful difference for this community.

## Issues
- Please check existing issues (even closed ones) before opening a new issue.
- For any bug reports, please include as much information as possible:
  - Reproduction steps.
  - What you said vs what was transcribed.
  - Include raw log output by setting KVX_DEBUG_LOG_RAW_TEXT = 1 in the Environment Variables.
  - Which app you were using when the unexpected behavior happened.
  - Include a test case that reproduces the bug, if possible.

## Pull Requests

### Getting Started

- Please don't open a pull request if you don't plan to see it through.
- Adhere to the existing code style.
- Squash your local commits into one commit before submitting the pull request.
- One logical change per PR.
- Avoid unrelated refactors.
- Add tests if relevant.
- Keep all docs up-to-date with your changes.
- If you must refactor, do it in a separate PR.
- AI assisted coding is MORE than fine, but keep the codebase clean.
- Do the pull request from a new branch. Never the default branch (`main`).


### Submission

- Make sure that all global tests are green.
- Give the pull request a clear title and description. It's your time to let everyone know why this change matters.
- Make sure the “Allow edits from maintainers” checkbox is checked. This will help pull requests move along quicker and be merged sooner.
- Make sure to reference any issues your pull request fixes (e.g. `Fixes #123`).

### Review

- Please push new commits when doing changes to the pull request. Remaining commits will be squashed when merging.
- Review your diff after each commit to catch any mistakes early.
- Be patient with reviews. I'm one person at the moment, but would love help. So if that's you, reach out!
- Thank you for your contribution! Let's make this tool better together! ❤️





