# horologium

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

### Local agent commands

The repo ships with `.opencode/command` as a repository-relative symlink to
`.claude/commands`. Note that this is intentionally asymmetric: `.opencode/command`
(singular) is a single entry point that points to the `.claude/commands` (plural)
directory. When adding or inspecting commands, use the `.claude/commands` path
for the actual command definitions; the `.opencode/command` symlink exists for
tooling compatibility. If the symlink is missing, recreate it from the repo root:

```sh
ln -s ../.claude/commands .opencode/command
```

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
